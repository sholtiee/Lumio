import CoreGraphics
import Foundation
import IOKit
import LumioKit

/// An Apple Silicon DDC/CI channel. IOAVService is a CF object with no thread
/// affinity; Lumio only touches it from `DDCController`'s serial queue.
final class AVService: @unchecked Sendable {
    let ref: IOAVService
    init(_ ref: IOAVService) { self.ref = ref }
}

/// Facts about display panels that CoreGraphics does not expose: the
/// marketing name and the DDC channel. Read from the IORegistry, where each
/// framebuffer node (`IOMobileFramebufferShim`, `AppleCLCD2` on older chips)
/// is followed by the `DCPAVServiceProxy` for the same port.
enum DisplayRegistry {
    struct Panel {
        let vendor: UInt32
        let model: UInt32
        let serial: UInt32
        let name: String?
        var service: AVService?
    }

    static func panels() -> [Panel] {
        var iterator = io_iterator_t()
        let root = IORegistryGetRootEntry(kIOMainPortDefault)
        defer { IOObjectRelease(root) }
        guard IORegistryEntryCreateIterator(root, kIOServicePlane, IOOptionBits(kIORegistryIterateRecursively), &iterator) == KERN_SUCCESS else {
            return []
        }
        defer { IOObjectRelease(iterator) }

        var panels: [Panel] = []
        var awaitingService: Int?
        while case let entry = IOIteratorNext(iterator), entry != 0 {
            defer { IOObjectRelease(entry) }
            switch name(of: entry) {
            case "IOMobileFramebufferShim", "AppleCLCD2":
                if let panel = panel(from: entry) {
                    panels.append(panel)
                    awaitingService = panels.count - 1
                }
            case "DCPAVServiceProxy":
                guard let index = awaitingService else { continue }
                awaitingService = nil
                guard string(entry, "Location") == "External",
                      let service = IOAVServiceCreateWithService(kCFAllocatorDefault, entry) else { continue }
                panels[index].service = AVService(service)
            default:
                continue
            }
        }
        return panels
    }

    /// Best panel for a CoreGraphics display: vendor and model must match,
    /// a matching serial wins among identical monitors.
    static func match(_ identity: DisplayIdentity, in panels: [Panel]) -> Panel? {
        let candidates = panels.filter { $0.vendor == identity.vendor && $0.model == identity.model }
        return candidates.first { $0.serial == identity.serial } ?? candidates.first
    }

    private static func panel(from entry: io_registry_entry_t) -> Panel? {
        guard let attributes = IORegistryEntryCreateCFProperty(entry, "DisplayAttributes" as CFString, kCFAllocatorDefault, 0)?
                .takeRetainedValue() as? [String: Any],
              let product = attributes["ProductAttributes"] as? [String: Any] else { return nil }
        let vendor = (product["LegacyManufacturerID"] as? NSNumber)?.uint32Value
            ?? (product["ManufacturerID"] as? String).flatMap(pnpID) ?? 0
        return Panel(
            vendor: vendor,
            model: (product["ProductID"] as? NSNumber)?.uint32Value ?? 0,
            serial: (product["SerialNumber"] as? NSNumber)?.uint32Value ?? 0,
            name: product["ProductName"] as? String,
            service: nil
        )
    }

    /// "DEL" → 0x10AC, the compressed EDID manufacturer ID.
    private static func pnpID(_ code: String) -> UInt32? {
        let letters = Array(code.uppercased().unicodeScalars)
        guard letters.count == 3, letters.allSatisfy({ (65...90).contains($0.value) }) else { return nil }
        return letters.reduce(0) { ($0 << 5) | ($1.value - 64) }
    }

    private static func name(of entry: io_registry_entry_t) -> String {
        var buffer = [CChar](repeating: 0, count: 128)
        IORegistryEntryGetName(entry, &buffer)
        let bytes = buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
        return String(decoding: bytes, as: UTF8.self)
    }

    private static func string(_ entry: io_registry_entry_t, _ key: String) -> String? {
        IORegistryEntryCreateCFProperty(entry, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? String
    }
}
