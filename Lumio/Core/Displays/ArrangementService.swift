import CoreGraphics

/// Arrangement-level changes: main display and plain (non-Sharp) mirroring.
enum ArrangementService {
    /// The main display is whichever sits at the global origin, so shift every
    /// drawable display by the target's offset.
    @discardableResult
    static func makeMain(_ id: CGDirectDisplayID) -> Bool {
        let target = CGDisplayBounds(id).origin
        guard target != .zero else { return true }
        var config: CGDisplayConfigRef?
        guard CGBeginDisplayConfiguration(&config) == .success else { return false }
        for display in DisplayList.active() {
            let origin = CGDisplayBounds(display).origin
            CGConfigureDisplayOrigin(config, display, Int32(origin.x - target.x), Int32(origin.y - target.y))
        }
        return CGCompleteDisplayConfiguration(config, .permanently) == .success
    }

    /// Mirrors `id` onto `master`, or stops mirroring when `master` is nil.
    @discardableResult
    static func mirror(_ id: CGDirectDisplayID, of master: CGDirectDisplayID?) -> Bool {
        var config: CGDisplayConfigRef?
        guard CGBeginDisplayConfiguration(&config) == .success else { return false }
        CGConfigureDisplayMirrorOfDisplay(config, id, master ?? kCGNullDirectDisplay)
        return CGCompleteDisplayConfiguration(config, .permanently) == .success
    }
}
