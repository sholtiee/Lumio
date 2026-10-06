import Foundation

/// DDC/CI (VESA MCCS) packet encoding over I²C.
public enum DDCProtocol {
    /// 7-bit I²C address of the monitor's DDC/CI endpoint (0x6E on the wire).
    public static let chipAddress: UInt32 = 0x37
    /// Host "source address" byte, passed as the I²C sub-address.
    public static let hostAddress: UInt32 = 0x51
    public static let replyLength = 11

    public enum VCP: UInt8, Sendable {
        case brightness = 0x10
        case contrast = 0x12
        case volume = 0x62
        case audioMute = 0x8D
    }

    /// Set VCP feature: length, opcode 0x03, code, value, checksum.
    public static func setPacket(_ code: UInt8, value: UInt16) -> [UInt8] {
        withChecksum([0x84, 0x03, code, UInt8(value >> 8), UInt8(value & 0xFF)])
    }

    /// Get VCP feature request: length, opcode 0x01, code, checksum.
    public static func getPacket(_ code: UInt8) -> [UInt8] {
        withChecksum([0x82, 0x01, code])
    }

    /// Parses a "VCP feature reply" (opcode 0x02). Tolerates a leading
    /// address byte, which some adapters include and some do not.
    public static func parseReply(_ bytes: [UInt8], code: UInt8) -> (current: UInt16, max: UInt16)? {
        guard bytes.count >= 8 else { return nil }
        for i in 0...(bytes.count - 8) where bytes[i] == 0x02 && bytes[i + 1] == 0x00 && bytes[i + 2] == code {
            let max = UInt16(bytes[i + 4]) << 8 | UInt16(bytes[i + 5])
            let current = UInt16(bytes[i + 6]) << 8 | UInt16(bytes[i + 7])
            guard max > 0, current <= max else { return nil }
            return (current, max)
        }
        return nil
    }

    /// Checksum is the XOR of the destination address (0x6E), the source
    /// address (0x51) and every payload byte.
    static func withChecksum(_ payload: [UInt8]) -> [UInt8] {
        let seed = UInt8(chipAddress << 1) ^ UInt8(hostAddress)
        return payload + [payload.reduce(seed, ^)]
    }
}

/// Brightness key behaviour, matching macOS: 16 steps, or 64 with ⌥⇧.
public enum BrightnessStep {
    public static func next(from value: Double, up: Bool, fine: Bool) -> Double {
        let steps = fine ? 64.0 : 16.0
        let snapped = (value * steps).rounded() / steps
        let delta = (up ? 1 : -1) / steps
        return min(max(snapped + delta, 0), 1)
    }
}
