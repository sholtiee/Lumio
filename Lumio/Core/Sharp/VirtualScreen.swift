import CoreGraphics
import Foundation
import LumioKit

/// One CGVirtualDisplay. The display exists exactly as long as this object.
@MainActor
final class VirtualScreen {
    /// "LU" — marks displays Lumio created so they never show up as physical ones.
    nonisolated static let vendorID: UInt32 = 0x4C55

    let display: CGVirtualDisplay
    let modes: [PointSize]
    let refreshRate: Double

    var id: CGDirectDisplayID { display.displayID }

    nonisolated static func isLumio(_ id: CGDirectDisplayID) -> Bool {
        CGDisplayVendorNumber(id) == vendorID
    }

    private init(display: CGVirtualDisplay, modes: [PointSize], refreshRate: Double) {
        self.display = display
        self.modes = modes
        self.refreshRate = refreshRate
    }

    /// Creates a HiDPI-capable stand-in for a physical panel.
    ///
    /// WindowServer refuses to create a virtual display for a moment after a
    /// previous one with the same serial goes away (e.g. toggling Sharp mode
    /// quickly), so creation is retried for a few seconds.
    static func make(
        name: String,
        identity: DisplayIdentity,
        native: PointSize,
        sizeInMillimeters: CGSize,
        refreshRate: Double
    ) async -> VirtualScreen? {
        let modes = HiDPIModeCatalog.modes(forNative: native)
        guard !modes.isEmpty else { return nil }
        let framebuffer = HiDPIModeCatalog.framebuffer(for: modes)

        let descriptor = CGVirtualDisplayDescriptor()
        descriptor.setDispatchQueue(.main)
        descriptor.name = name
        descriptor.maxPixelsWide = UInt32(framebuffer.width)
        descriptor.maxPixelsHigh = UInt32(framebuffer.height)
        descriptor.sizeInMillimeters = sizeInMillimeters.width > 0 ? sizeInMillimeters : estimatedSize(native)
        descriptor.vendorID = vendorID
        descriptor.productID = identity.model & 0xFFFF
        descriptor.serialNum = identity.virtualSerial

        let settings = CGVirtualDisplaySettings()
        settings.hiDPI = 1
        settings.modes = modes.map {
            CGVirtualDisplayMode(width: UInt($0.width), height: UInt($0.height), refreshRate: refreshRate)
        }

        for _ in 0..<12 {
            if let display = CGVirtualDisplay(descriptor: descriptor) {
                guard display.apply(settings) else { return nil }
                let screen = VirtualScreen(display: display, modes: modes, refreshRate: refreshRate)
                await screen.waitUntilOnline()
                return screen
            }
            try? await Task.sleep(for: .milliseconds(400))
        }
        return nil
    }

    /// Switches the rendered resolution. The 2× variant is always the one we want.
    @discardableResult
    func select(_ size: PointSize) -> Bool {
        guard let mode = ModeService.find(on: id, size: size, hiDPI: true, refresh: refreshRate) else { return false }
        return ModeService.apply(mode, to: id)
    }

    var currentSize: PointSize? {
        ModeService.current(of: id).map { PointSize(width: $0.width, height: $0.height) }
    }

    private func waitUntilOnline() async {
        for _ in 0..<30 {
            if DisplayList.online().contains(id), ModeService.current(of: id) != nil { return }
            try? await Task.sleep(for: .milliseconds(100))
        }
    }

    /// ~109 ppi, the density of a 27" 1440p panel, when EDID has no size.
    private static func estimatedSize(_ native: PointSize) -> CGSize {
        CGSize(width: Double(native.width) / 109 * 25.4, height: Double(native.height) / 109 * 25.4)
    }
}

enum DisplayList {
    static func online() -> [CGDirectDisplayID] {
        list(CGGetOnlineDisplayList)
    }

    /// Drawable displays — excludes displays that only mirror another.
    static func active() -> [CGDirectDisplayID] {
        list(CGGetActiveDisplayList)
    }

    private static func list(
        _ fetch: (UInt32, UnsafeMutablePointer<CGDirectDisplayID>?, UnsafeMutablePointer<UInt32>?) -> CGError
    ) -> [CGDirectDisplayID] {
        var ids = [CGDirectDisplayID](repeating: 0, count: 32)
        var count: UInt32 = 0
        guard fetch(UInt32(ids.count), &ids, &count) == .success else { return [] }
        return Array(ids.prefix(Int(count)))
    }
}
