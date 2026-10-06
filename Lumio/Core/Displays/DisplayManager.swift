import AppKit
import CoreGraphics
import LumioKit
import Observation

/// The list of physical displays, kept current through CoreGraphics
/// reconfiguration callbacks. Lumio's own virtual displays are folded into
/// the physical display they stand in for.
@MainActor
@Observable
final class DisplayManager {
    private(set) var displays: [Display] = []
    @ObservationIgnored private(set) var panels: [DisplayRegistry.Panel] = []
    @ObservationIgnored var onChange: (() -> Void)?
    @ObservationIgnored private var refreshTask: Task<Void, Never>?
    @ObservationIgnored private let engine: SharpModeEngine
    @ObservationIgnored private let profiles: ProfileStore

    fileprivate static weak var current: DisplayManager?

    init(engine: SharpModeEngine, profiles: ProfileStore) {
        self.engine = engine
        self.profiles = profiles
    }

    func start() {
        Self.current = self
        CGDisplayRegisterReconfigurationCallback(displayReconfigured, nil)
        refresh()
    }

    func display(withDesktopID id: CGDirectDisplayID) -> Display? {
        displays.first { $0.desktopID == id || $0.id == id }
    }

    func display(for identity: DisplayIdentity) -> Display? {
        displays.first { $0.identity == identity }
    }

    /// macOS reports a burst of callbacks per change; coalesce them.
    func scheduleRefresh(after delay: Duration = .milliseconds(350)) {
        refreshTask?.cancel()
        refreshTask = Task {
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            refresh()
        }
    }

    func refresh() {
        panels = DisplayRegistry.panels()
        let physical = DisplayList.online().filter { !VirtualScreen.isLumio($0) }
        let identities = Dictionary(uniqueKeysWithValues: physical.map { ($0, Self.identity(of: $0)) })
        engine.reconcile(present: identities)

        let fresh = physical
            .map { makeDisplay($0, identity: identities[$0]!) }
            .sorted { lhs, rhs in
                lhs.isBuiltin != rhs.isBuiltin ? lhs.isBuiltin : CGDisplayBounds(lhs.desktopID).minX < CGDisplayBounds(rhs.desktopID).minX
            }
        if fresh != displays { displays = fresh }
        onChange?()
    }

    static func identity(of id: CGDirectDisplayID) -> DisplayIdentity {
        DisplayIdentity(vendor: CGDisplayVendorNumber(id), model: CGDisplayModelNumber(id), serial: CGDisplaySerialNumber(id))
    }

    private func makeDisplay(_ id: CGDirectDisplayID, identity: DisplayIdentity) -> Display {
        let sharpID = engine.virtualID(for: identity).flatMap { DisplayList.online().contains($0) ? $0 : nil }
        let desktopID = sharpID ?? id
        let native = ModeService.nativePixels(of: id)
        let mirrorMaster = CGDisplayMirrorsDisplay(id)
        let isBuiltin = CGDisplayIsBuiltin(id) != 0

        return Display(
            id: id,
            identity: identity,
            name: name(for: id, desktopID: desktopID, identity: identity, isBuiltin: isBuiltin),
            isBuiltin: isBuiltin,
            isMain: CGDisplayIsMain(desktopID) != 0,
            current: ModeService.current(of: desktopID).map(DisplayMode.init),
            output: ModeService.current(of: id).map(DisplayMode.init),
            nativePixels: native,
            physicalSizeMM: CGDisplayScreenSize(id),
            hasUsefulHiDPI: ModeService.hasUsefulHiDPI(id, native: native),
            sharpVirtualID: sharpID,
            mirrorsDisplay: mirrorMaster == kCGNullDirectDisplay || mirrorMaster == sharpID ? nil : mirrorMaster
        )
    }

    private func name(for id: CGDirectDisplayID, desktopID: CGDirectDisplayID, identity: DisplayIdentity, isBuiltin: Bool) -> String {
        if let screen = NSScreen.screens.first(where: { $0.displayID == desktopID }) {
            return screen.localizedName
        }
        if isBuiltin { return String(localized: "Built-in Display") }
        return DisplayRegistry.match(identity, in: panels)?.name
            ?? profiles.profile(for: identity)?.name
            ?? String(localized: "External Display")
    }
}

private func displayReconfigured(_ id: CGDirectDisplayID, _ flags: CGDisplayChangeSummaryFlags, _: UnsafeMutableRawPointer?) {
    guard !flags.contains(.beginConfigurationFlag) else { return }
    Task { @MainActor in DisplayManager.current?.scheduleRefresh() }
}

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }
}
