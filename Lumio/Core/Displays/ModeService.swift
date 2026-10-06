import CoreGraphics
import LumioKit

/// Thin wrapper over the public CoreGraphics mode APIs.
enum ModeService {
    /// IOKit's kDisplayModeNativeFlag.
    private static let nativeFlag: UInt32 = 0x0200_0000

    /// All modes, including the 2× variants macOS hides by default.
    static func modes(of id: CGDirectDisplayID) -> [CGDisplayMode] {
        let options = [kCGDisplayShowDuplicateLowResolutionModes: kCFBooleanTrue] as CFDictionary
        let all = CGDisplayCopyAllDisplayModes(id, options) as? [CGDisplayMode] ?? []
        return all.filter { $0.isUsableForDesktopGUI() }
    }

    static func current(of id: CGDirectDisplayID) -> CGDisplayMode? {
        CGDisplayCopyDisplayMode(id)
    }

    /// The panel's native 1× mode at the best refresh rate, or the preferred rate if offered.
    static func nativeMode(of id: CGDirectDisplayID, preferredRefresh: Double? = nil) -> CGDisplayMode? {
        let flat = modes(of: id).filter { $0.pixelWidth == $0.width }
        let flagged = flat.filter { $0.ioFlags & nativeFlag != 0 }
        let largestArea = flat.map { $0.pixelWidth * $0.pixelHeight }.max()
        let candidates = flagged.isEmpty ? flat.filter { $0.pixelWidth * $0.pixelHeight == largestArea } : flagged
        if let preferredRefresh, let match = candidates.first(where: { abs($0.refreshRate - preferredRefresh) < 0.5 }) {
            return match
        }
        return candidates.max { $0.refreshRate < $1.refreshRate }
    }

    static func nativePixels(of id: CGDirectDisplayID) -> PointSize {
        if let native = nativeMode(of: id) {
            return PointSize(width: native.pixelWidth, height: native.pixelHeight)
        }
        return PointSize(width: Int(CGDisplayPixelsWide(id)), height: Int(CGDisplayPixelsHigh(id)))
    }

    /// True when macOS already offers a HiDPI mode that is not uselessly
    /// large — e.g. 4K and 5K panels. A 1440p panel only gets "looks like
    /// 1280×720", which does not count.
    static func hasUsefulHiDPI(_ id: CGDirectDisplayID, native: PointSize) -> Bool {
        let widest = modes(of: id).filter { $0.pixelWidth > $0.width }.map(\.width).max() ?? 0
        return Double(widest) >= Double(native.width) * 0.6
    }

    /// Distinct resolutions for a picker, largest first.
    static func resolutionChoices(of id: CGDirectDisplayID) -> [DisplayMode] {
        var seen = Set<String>()
        return modes(of: id)
            .map(DisplayMode.init)
            .filter { $0.size.width >= 1024 }
            .sorted { ($0.size, $0.isHiDPI ? 1 : 0, $0.refreshRate) > ($1.size, $1.isHiDPI ? 1 : 0, $1.refreshRate) }
            .filter { seen.insert("\($0.size.width)x\($0.size.height)/\($0.isHiDPI)").inserted }
    }

    static func refreshRates(of id: CGDirectDisplayID, matching mode: DisplayMode) -> [Double] {
        let rates = modes(of: id)
            .map(DisplayMode.init)
            .filter { $0.size == mode.size && $0.isHiDPI == mode.isHiDPI && $0.refreshRate > 0 }
            .map(\.refreshRate)
        return Array(Set(rates.map { $0.rounded() })).sorted(by: >)
    }

    /// Finds the closest real mode: exact size and scale, nearest refresh rate.
    static func find(on id: CGDirectDisplayID, size: PointSize, hiDPI: Bool, refresh: Double?) -> CGDisplayMode? {
        let matches = modes(of: id).filter {
            $0.width == size.width && $0.height == size.height && ($0.pixelWidth > $0.width) == hiDPI
        }
        guard let refresh else { return matches.max { $0.refreshRate < $1.refreshRate } }
        return matches.min { abs($0.refreshRate - refresh) < abs($1.refreshRate - refresh) }
    }

    @discardableResult
    static func apply(_ mode: CGDisplayMode, to id: CGDirectDisplayID) -> Bool {
        var config: CGDisplayConfigRef?
        guard CGBeginDisplayConfiguration(&config) == .success else { return false }
        CGConfigureDisplayWithDisplayMode(config, id, mode, nil)
        return CGCompleteDisplayConfiguration(config, .permanently) == .success
    }
}
