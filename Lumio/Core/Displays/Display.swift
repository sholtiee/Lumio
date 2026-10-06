import CoreGraphics
import LumioKit

/// A display mode reduced to what the UI and profiles care about.
struct DisplayMode: Hashable, Identifiable, Sendable {
    let size: PointSize
    let pixels: PointSize
    let refreshRate: Double

    init(size: PointSize, pixels: PointSize, refreshRate: Double) {
        self.size = size
        self.pixels = pixels
        self.refreshRate = refreshRate
    }

    init(_ mode: CGDisplayMode) {
        self.init(
            size: PointSize(width: mode.width, height: mode.height),
            pixels: PointSize(width: mode.pixelWidth, height: mode.pixelHeight),
            refreshRate: mode.refreshRate
        )
    }

    var isHiDPI: Bool { pixels.width > size.width }
    var id: String { "\(size.width)x\(size.height)/\(pixels.width)@\(Int(refreshRate.rounded()))" }
    var refreshLabel: String { refreshRate > 0 ? "\(Int(refreshRate.rounded())) Hz" : "" }
}

/// A physical display as the user thinks of it. When Sharp mode is on, the
/// virtual display that renders for it is folded into this value rather than
/// listed separately.
struct Display: Identifiable, Equatable, Sendable {
    let id: CGDirectDisplayID
    let identity: DisplayIdentity
    var name: String
    let isBuiltin: Bool
    var isMain: Bool
    /// What the desktop renders at: the virtual display's mode when Sharp.
    var current: DisplayMode?
    /// What travels over the cable.
    var output: DisplayMode?
    let nativePixels: PointSize
    let physicalSizeMM: CGSize
    let hasUsefulHiDPI: Bool
    var sharpVirtualID: CGDirectDisplayID?
    /// Another physical display this one mirrors (not counting Sharp mode).
    var mirrorsDisplay: CGDirectDisplayID?

    var isSharp: Bool { sharpVirtualID != nil }
    /// The display ID that owns the desktop — the one windows and NSScreen live on.
    var desktopID: CGDirectDisplayID { sharpVirtualID ?? id }
    var benefitsFromSharpMode: Bool { !isBuiltin && !hasUsefulHiDPI }

    var pixelsPerInch: Double? {
        guard physicalSizeMM.width > 0 else { return nil }
        return Double(nativePixels.width) / (physicalSizeMM.width / 25.4)
    }

    var symbolName: String { isBuiltin ? "laptopcomputer" : "display" }
}
