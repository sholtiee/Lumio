import CoreGraphics
import Foundation
import LumioKit

/// Sharp mode: render a non-Retina panel at 2× on a virtual display and let
/// the panel mirror it. WindowServer downsamples the 2× framebuffer onto the
/// panel, which gives Retina-quality text on 1440p and 1080p monitors.
@MainActor
final class SharpModeEngine {
    enum Failure: LocalizedError {
        case virtualDisplayUnavailable
        case mirroringFailed

        var errorDescription: String? {
            switch self {
            case .virtualDisplayUnavailable: String(localized: "macOS did not create the virtual display. Try again in a few seconds.")
            case .mirroringFailed: String(localized: "macOS refused to mirror the display. Try reconnecting the cable.")
            }
        }
    }

    private struct Session {
        var physicalID: CGDirectDisplayID
        let screen: VirtualScreen
    }

    private var sessions: [DisplayIdentity: Session] = [:]
    private var busy: Set<DisplayIdentity> = []

    func virtualID(for identity: DisplayIdentity) -> CGDirectDisplayID? {
        sessions[identity]?.screen.id
    }

    func modes(for identity: DisplayIdentity) -> [PointSize] {
        sessions[identity]?.screen.modes ?? []
    }

    func isBusy(_ identity: DisplayIdentity) -> Bool {
        busy.contains(identity)
    }

    func enable(_ display: Display, resolution: PointSize?) async throws {
        guard sessions[display.identity] == nil, busy.insert(display.identity).inserted else { return }
        defer { busy.remove(display.identity) }

        let physical = display.id
        // Every panel pixel must be used, so drive the panel at its native mode.
        let refresh = ModeService.current(of: physical)?.refreshRate
        if let native = ModeService.nativeMode(of: physical, preferredRefresh: refresh),
           ModeService.current(of: physical).map(DisplayMode.init) != DisplayMode(native) {
            ModeService.apply(native, to: physical)
        }
        let outputRefresh = ModeService.current(of: physical)?.refreshRate ?? 0
        let origin = CGDisplayBounds(physical).origin

        guard let screen = await VirtualScreen.make(
            name: display.name,
            identity: display.identity,
            native: display.nativePixels,
            sizeInMillimeters: display.physicalSizeMM,
            refreshRate: outputRefresh > 0 ? outputRefresh : 60
        ) else { throw Failure.virtualDisplayUnavailable }

        let target = resolution.flatMap { screen.modes.contains($0) ? $0 : nil }
            ?? HiDPIModeCatalog.preferredDefault(forNative: display.nativePixels, in: screen.modes)
        if let target { screen.select(target) }

        // Mirroring occasionally fails right after the virtual display appears.
        for _ in 0..<4 {
            if Self.mirror(physical, onto: screen.id, at: origin) {
                sessions[display.identity] = Session(physicalID: physical, screen: screen)
                return
            }
            try? await Task.sleep(for: .milliseconds(500))
        }
        throw Failure.mirroringFailed
    }

    func disable(_ identity: DisplayIdentity) {
        guard let session = sessions.removeValue(forKey: identity) else { return }
        restore(session)
    }

    /// Called on quit: hand every panel back to macOS before the virtual displays vanish.
    func disableAll() {
        for identity in Array(sessions.keys) { disable(identity) }
    }

    @discardableResult
    func setResolution(_ size: PointSize, for identity: DisplayIdentity) -> Bool {
        sessions[identity]?.screen.select(size) ?? false
    }

    /// Keeps sessions in step with the hardware after any display change:
    /// unplugged panels lose their virtual display (or windows would be
    /// stranded on an invisible screen); reconnected ones are mirrored again.
    func reconcile(present: [CGDirectDisplayID: DisplayIdentity]) {
        for (identity, session) in sessions where !busy.contains(identity) {
            guard let physical = present.first(where: { $0.value == identity })?.key else {
                sessions[identity] = nil
                continue
            }
            sessions[identity]?.physicalID = physical
            if CGDisplayMirrorsDisplay(physical) != session.screen.id {
                Self.mirror(physical, onto: session.screen.id, at: CGDisplayBounds(session.screen.id).origin)
            }
        }
    }

    // MARK: - Display configuration

    @discardableResult
    private static func mirror(_ physical: CGDirectDisplayID, onto virtual: CGDirectDisplayID, at origin: CGPoint) -> Bool {
        var config: CGDisplayConfigRef?
        guard CGBeginDisplayConfiguration(&config) == .success else { return false }
        // Put the virtual display where the panel was, so the arrangement and
        // the main display (origin 0,0) stay the same.
        CGConfigureDisplayOrigin(config, virtual, Int32(origin.x), Int32(origin.y))
        guard CGConfigureDisplayMirrorOfDisplay(config, physical, virtual) == .success else {
            CGCancelDisplayConfiguration(config)
            return false
        }
        return CGCompleteDisplayConfiguration(config, .forSession) == .success
    }

    private func restore(_ session: Session) {
        guard DisplayList.online().contains(session.physicalID) else { return }
        let origin = CGDisplayBounds(session.screen.id).origin
        var config: CGDisplayConfigRef?
        guard CGBeginDisplayConfiguration(&config) == .success else { return }
        CGConfigureDisplayMirrorOfDisplay(config, session.physicalID, kCGNullDirectDisplay)
        CGConfigureDisplayOrigin(config, session.physicalID, Int32(origin.x), Int32(origin.y))
        CGCompleteDisplayConfiguration(config, .forSession)
    }
}
