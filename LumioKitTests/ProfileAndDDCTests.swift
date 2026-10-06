import Foundation
import Testing
@testable import LumioKit

struct ProfileBookTests {
    let dell = DisplayIdentity(vendor: 0x10AC, model: 0xA0C4, serial: 0x4A4B4C)

    @Test func exactMatchWins() {
        var book = ProfileBook()
        book.update(dell) { $0.sharpMode = true }
        #expect(book.profile(for: dell)?.sharpMode == true)
    }

    @Test func sameModelFallbackWhenUnambiguous() {
        var book = ProfileBook()
        book.update(dell) { $0.sharpMode = true }
        let otherPort = DisplayIdentity(vendor: dell.vendor, model: dell.model, serial: 0)
        #expect(book.profile(for: otherPort)?.sharpMode == true)

        book.update(DisplayIdentity(vendor: dell.vendor, model: dell.model, serial: 7)) { $0.sharpMode = false }
        #expect(book.profile(for: otherPort) == nil)
    }

    @Test func differentModelDoesNotMatch() {
        var book = ProfileBook()
        book.update(dell) { $0.sharpMode = true }
        #expect(book.profile(for: DisplayIdentity(vendor: dell.vendor, model: 1, serial: dell.serial)) == nil)
    }

    @Test func roundTripsThroughJSON() throws {
        var book = ProfileBook()
        book.update(dell) {
            $0.sharpMode = true
            $0.sharpResolution = PointSize(width: 2560, height: 1440)
            $0.brightness = 0.4
        }
        let data = try JSONEncoder().encode(book)
        #expect(try JSONDecoder().decode(ProfileBook.self, from: data) == book)
    }

    @Test func virtualSerialIsStableAndNonZero() {
        #expect(dell.virtualSerial == dell.virtualSerial)
        #expect(DisplayIdentity(vendor: 0, model: 0, serial: 0).virtualSerial != 0)
    }
}

struct DDCProtocolTests {
    @Test func setBrightnessPacket() {
        // 0x6E ^ 0x51 ^ 0x84 ^ 0x03 ^ 0x10 ^ 0x00 ^ 0x32
        #expect(DDCProtocol.setPacket(0x10, value: 50) == [0x84, 0x03, 0x10, 0x00, 0x32, 0x9A])
    }

    @Test func getPacket() {
        #expect(DDCProtocol.getPacket(0x10) == [0x82, 0x01, 0x10, 0xAC])
    }

    @Test func parsesReplyWithAndWithoutAddressByte() {
        let body: [UInt8] = [0x88, 0x02, 0x00, 0x10, 0x00, 0x00, 0x64, 0x00, 0x2D, 0x00]
        #expect(DDCProtocol.parseReply([0x6E] + body, code: 0x10)! == (current: 45, max: 100))
        #expect(DDCProtocol.parseReply(body, code: 0x10)! == (current: 45, max: 100))
    }

    @Test func rejectsGarbage() {
        #expect(DDCProtocol.parseReply([0x6E, 0x80, 0xBE, 0, 0, 0, 0, 0, 0, 0, 0], code: 0x10) == nil)
        #expect(DDCProtocol.parseReply([0x6E, 0x88, 0x02, 0x01, 0x10, 0, 0, 0x64, 0, 0x2D, 0], code: 0x10) == nil)
    }

    @Test func brightnessStepsMatchMacOS() {
        #expect(BrightnessStep.next(from: 0.5, up: true, fine: false) == 0.5625)
        #expect(BrightnessStep.next(from: 1, up: true, fine: false) == 1)
        #expect(BrightnessStep.next(from: 0.01, up: false, fine: false) == 0)
        #expect(BrightnessStep.next(from: 0.5, up: false, fine: true) == 0.484375)
    }
}
