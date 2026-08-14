import Foundation

/// Classification of the bytes a monitor returns for a DDC/CI Get VCP request.
///
/// Lives in Models, away from the IOKit calls, so the frame rules can be tested
/// without hardware — the distinction between the cases decides whether the app
/// drives a monitor's backlight or dims it in software, and getting it wrong is
/// invisible until someone drags a slider that does nothing.
enum DDCReply: Equatable {
    /// A well-formed Get VCP Feature Reply.
    case value(current: UInt16, max: UInt16)

    /// A well-formed DDC/CI null message: `[0x6E, 0x80, checksum]`, length zero.
    ///
    /// The monitor received the request and is declining to answer. Monitors send
    /// this when DDC/CI is switched off in their OSD, or when the link they are on
    /// does not carry the channel. Crucially they still ACK at the I2C layer, so
    /// writes to them "succeed" and a caller judging capability on writes alone
    /// concludes hardware brightness works.
    case refused

    /// Anything else: truncated, stale EDID bytes, a wrong opcode echo, garbage.
    /// Says nothing about whether the monitor honours writes — some monitors accept
    /// Set VCP while never answering a Get.
    case malformed

    /// The DDC/CI virtual host address, XORed into every checksum.
    private static let hostAddress: UInt8 = 0x50
    /// The display's source address, echoed as the first byte of any reply.
    private static let sourceAddress: UInt8 = 0x6E
    /// Length byte for a zero-length (null) message.
    private static let nullLength: UInt8 = 0x80

    /// Classifies a reply buffer for a Get VCP request of `command`.
    ///
    /// - Parameters:
    ///   - bytes: The raw reply, as read from the bus.
    ///   - command: The VCP opcode that was requested; a reply echoing anything else
    ///     belongs to some other transaction and is not trusted.
    static func classify(_ bytes: [UInt8], command: UInt8) -> DDCReply {
        guard bytes.count >= 3, bytes[0] == sourceAddress else { return .malformed }

        // Checked first: a null message is well-formed, just empty, so the general
        // reply validation below would otherwise lump it in with garbage.
        if bytes[1] == nullLength {
            let expected = hostAddress ^ sourceAddress ^ nullLength
            return bytes[2] == expected ? .refused : .malformed
        }

        // Get VCP Feature Reply:
        //   [0] 0x6E source address
        //   [1] 0x88 length byte (0x80 | 8)
        //   [2] 0x02 Get VCP Feature Reply opcode
        //   [3] result code, 0x00 = no error
        //   [4] echo of the requested VCP opcode
        //   [5] VCP type code
        //   [6..7] max value, big endian
        //   [8..9] current value, big endian
        //   [10] checksum
        guard bytes.count >= 10,
              bytes[2] == 0x02,
              bytes[3] == 0x00,
              bytes[4] == command
        else { return .malformed }

        let max = UInt16(bytes[6]) << 8 | UInt16(bytes[7])
        let current = UInt16(bytes[8]) << 8 | UInt16(bytes[9])
        return .value(current: current, max: max)
    }
}
