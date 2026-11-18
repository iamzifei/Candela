import XCTest
@testable import Candela

/// `DisplayConnection.classify` turns flattened CoreDisplay / IORegistry signals into
/// the label under a display's name. The signal values here are the ones measured on
/// real hardware (notes/plans/20261118-connection-types-airplay-order.md).
final class DisplayConnectionTests: XCTestCase {
    private func classify(_ configure: (inout DisplayConnection.Signals) -> Void) -> DisplayConnection {
        var s = DisplayConnection.Signals()
        configure(&s)
        return DisplayConnection.classify(s)
    }

    func testBuiltinWinsOverEverything() {
        XCTAssertEqual(classify { $0.isBuiltin = true; $0.downstreamTransport = "DP" }, .builtin)
    }

    func testHDMIFromTransport() {
        // M28U on the MacBook's HDMI port: Transport = {Upstream=DP, Downstream=HDMI}.
        XCTAssertEqual(classify { $0.downstreamTransport = "HDMI"; $0.isHDMISink = true }, .hdmi)
    }

    func testDisplayPortFromTransport() {
        // VX1622 over USB-C: Transport = {Upstream=DP, Downstream=DP}.
        XCTAssertEqual(classify { $0.downstreamTransport = "DP" }, .displayPort)
        XCTAssertEqual(classify { $0.downstreamTransport = "dp" }, .displayPort)
    }

    func testTransportBeatsHDMISinkFlag() {
        // An HDMI-capable monitor plugged in over DisplayPort is a DisplayPort link.
        XCTAssertEqual(classify { $0.downstreamTransport = "DP"; $0.isHDMISink = true }, .displayPort)
    }

    func testHDMISinkFallbackWithoutTransport() {
        XCTAssertEqual(classify { $0.isHDMISink = true }, .hdmi)
    }

    func testAirPlay() {
        XCTAssertEqual(classify { $0.isAirPlay = true }, .airPlay)
        XCTAssertTrue(DisplayConnection.airPlay.isWireless)
    }

    func testSidecarWinsOverAirPlayFlag() {
        // A Sidecar session may also carry the AirPlay flag; the specific answer wins.
        XCTAssertEqual(classify { $0.isSidecar = true; $0.isAirPlay = true }, .sidecar)
    }

    func testVirtual() {
        XCTAssertEqual(classify { $0.isVirtual = true }, .virtual)
        XCTAssertFalse(DisplayConnection.virtual.isWireless)
    }

    func testUnknownIsExternal() {
        XCTAssertEqual(classify { _ in }, .external)
        XCTAssertEqual(classify { $0.downstreamTransport = "Something" }, .external)
    }

    func testPortLabelsAreNotTranslated() {
        XCTAssertEqual(DisplayConnection.hdmi.label, "HDMI")
        XCTAssertEqual(DisplayConnection.displayPort.label, "DisplayPort")
        XCTAssertEqual(DisplayConnection.airPlay.label, "AirPlay")
    }
}

final class DisplayOrderTests: XCTestCase {
    func testEmptySavedKeepsAutomaticOrder() {
        XCTAssertEqual(DisplayOrder.apply(saved: [], to: ["a", "b", "c"]), ["a", "b", "c"])
    }

    func testSavedOrderOverridesAutomatic() {
        XCTAssertEqual(DisplayOrder.apply(saved: ["c", "a", "b"], to: ["a", "b", "c"]), ["c", "a", "b"])
    }

    func testUnplacedDisplaysGoLastInAutomaticOrder() {
        XCTAssertEqual(DisplayOrder.apply(saved: ["b"], to: ["a", "b", "c"]), ["b", "a", "c"])
    }

    func testDisconnectedSavedEntriesAreIgnored() {
        XCTAssertEqual(DisplayOrder.apply(saved: ["x", "b", "a"], to: ["a", "b"]), ["b", "a"])
    }

    func testDuplicateSavedEntriesDoNotCrash() {
        XCTAssertEqual(DisplayOrder.apply(saved: ["b", "a", "b"], to: ["a", "b"]), ["b", "a"])
    }

    func testMoveUpAndDown() {
        XCTAssertEqual(DisplayOrder.move("b", by: -1, in: ["a", "b", "c"]), ["b", "a", "c"])
        XCTAssertEqual(DisplayOrder.move("b", by: 1, in: ["a", "b", "c"]), ["a", "c", "b"])
    }

    func testMoveAtEdgeOrUnknownIsNil() {
        XCTAssertNil(DisplayOrder.move("a", by: -1, in: ["a", "b"]))
        XCTAssertNil(DisplayOrder.move("b", by: 1, in: ["a", "b"]))
        XCTAssertNil(DisplayOrder.move("z", by: 1, in: ["a", "b"]))
    }

    func testMergeKeepsDisconnectedDisplaySlot() {
        // x is unplugged; after swapping a and b it still sits between them.
        XCTAssertEqual(DisplayOrder.merge(visible: ["b", "a"], into: ["a", "x", "b"]), ["b", "x", "a"])
    }

    func testMergeIntoEmptyIsVisibleOrder() {
        XCTAssertEqual(DisplayOrder.merge(visible: ["b", "a"], into: []), ["b", "a"])
    }

    func testMergeAppendsNewDisplays() {
        XCTAssertEqual(DisplayOrder.merge(visible: ["a", "c"], into: ["a"]), ["a", "c"])
    }

    func testRoundTripMoveThenApply() {
        // Moving the last display to the top, then reconnecting with a different
        // automatic order, keeps the user's order.
        let saved = DisplayOrder.merge(visible: DisplayOrder.move("c", by: -1, in: ["a", "c", "b"])!, into: [])
        XCTAssertEqual(DisplayOrder.apply(saved: saved, to: ["b", "a", "c"]), ["c", "a", "b"])
    }
}
