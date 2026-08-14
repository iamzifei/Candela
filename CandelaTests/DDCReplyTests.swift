import XCTest

/// `DDCReply` is compiled into this target directly (see project.yml, same route
/// as `DDCServiceMatcher`), so no `@testable import Candela` is needed.
///
/// The cases here are the real bytes two monitors on the same Mac return: a
/// ViewSonic VX1622-4K answering normally, and a Gigabyte M28U refusing. The
/// difference between "refused" and "malformed" decides whether the app drives
/// the backlight or dims in software, and on the refusing monitor the wrong
/// answer means the brightness slider moves and nothing happens.
final class DDCReplyTests: XCTestCase {

    private let brightness: UInt8 = 0x10

    // MARK: - Real replies

    func testParsesRealBrightnessReply() {
        // VX1622-4K at full brightness.
        let bytes: [UInt8] = [0x6E, 0x88, 0x02, 0x00, 0x10, 0x00, 0x00, 0x64, 0x00, 0x64, 0xA4, 0x00]
        XCTAssertEqual(DDCReply.classify(bytes, command: brightness),
                       .value(current: 100, max: 100))
    }

    func testParsesMidRangeBrightnessReply() {
        // M28U on one of the occasions it did answer: 50 of 100.
        let bytes: [UInt8] = [0x6E, 0x88, 0x02, 0x00, 0x10, 0x00, 0x00, 0x64, 0x00, 0x32, 0xF2, 0x00]
        XCTAssertEqual(DDCReply.classify(bytes, command: brightness),
                       .value(current: 50, max: 100))
    }

    func testRecognizesNullMessageAsRefusal() {
        // M28U's usual answer: length byte 0x80, checksum 0x50 ^ 0x6E ^ 0x80.
        let bytes: [UInt8] = [0x6E, 0x80, 0xBE, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
        XCTAssertEqual(DDCReply.classify(bytes, command: brightness), .refused)
    }

    // MARK: - Refusal is not guessed at

    func testNullLengthWithWrongChecksumIsMalformedNotRefusal() {
        // Garbage that happens to carry 0x80 in the length byte must not be read as a
        // deliberate refusal — that would drop a working monitor to software dimming.
        let bytes: [UInt8] = [0x6E, 0x80, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
        XCTAssertEqual(DDCReply.classify(bytes, command: brightness), .malformed)
    }

    func testWrongSourceAddressIsMalformed() {
        let bytes: [UInt8] = [0x00, 0x80, 0xBE, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
        XCTAssertEqual(DDCReply.classify(bytes, command: brightness), .malformed)
    }

    // MARK: - Malformed frames

    func testWrongOpcodeEchoIsMalformed() {
        // A reply to some other VCP request that arrived on this read.
        let bytes: [UInt8] = [0x6E, 0x88, 0x02, 0x00, 0x12, 0x00, 0x00, 0x64, 0x00, 0x64, 0xA6, 0x00]
        XCTAssertEqual(DDCReply.classify(bytes, command: brightness), .malformed)
    }

    func testNonZeroResultCodeIsMalformed() {
        let bytes: [UInt8] = [0x6E, 0x88, 0x02, 0x01, 0x10, 0x00, 0x00, 0x64, 0x00, 0x64, 0xA5, 0x00]
        XCTAssertEqual(DDCReply.classify(bytes, command: brightness), .malformed)
    }

    func testWrongReplyOpcodeIsMalformed() {
        let bytes: [UInt8] = [0x6E, 0x88, 0x03, 0x00, 0x10, 0x00, 0x00, 0x64, 0x00, 0x64, 0xA5, 0x00]
        XCTAssertEqual(DDCReply.classify(bytes, command: brightness), .malformed)
    }

    func testTruncatedFrameIsMalformed() {
        XCTAssertEqual(DDCReply.classify([0x6E, 0x88, 0x02, 0x00, 0x10], command: brightness),
                       .malformed)
    }

    func testEmptyFrameIsMalformed() {
        XCTAssertEqual(DDCReply.classify([], command: brightness), .malformed)
    }

    // MARK: - Payload decoding

    func testDecodesBigEndianValuesAboveOneByte() {
        // A monitor whose native DDC range is 0–1000, currently at 750.
        let bytes: [UInt8] = [0x6E, 0x88, 0x02, 0x00, 0x10, 0x00, 0x03, 0xE8, 0x02, 0xEE, 0x00, 0x00]
        XCTAssertEqual(DDCReply.classify(bytes, command: brightness),
                       .value(current: 750, max: 1000))
    }

    func testClassifiesOtherVCPCodes() {
        // Volume, so the command echo is checked against what was asked for rather
        // than hardcoded to brightness.
        let volume: UInt8 = 0x62
        let bytes: [UInt8] = [0x6E, 0x88, 0x02, 0x00, 0x62, 0x00, 0x00, 0x64, 0x00, 0x1E, 0x00, 0x00]
        XCTAssertEqual(DDCReply.classify(bytes, command: volume),
                       .value(current: 30, max: 100))
        XCTAssertEqual(DDCReply.classify(bytes, command: brightness), .malformed)
    }
}
