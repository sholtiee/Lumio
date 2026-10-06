import AppKit
import KeyboardShortcuts
import LumioKit
import Observation

/// Wires the services together and owns every user-facing action, so the
/// menu bar, Settings, hotkeys and media keys all go through one path.
@MainActor
@Observable
final class AppModel {
    let profiles = ProfileStore()
    let brightness = BrightnessController()
    @ObservationIgnored let engine = SharpModeEngine()
    let displays: DisplayManager
    @ObservationIgnored private let mediaKeys = MediaKeyTap()

    /// Displays whose Sharp mode is being switched on — the UI shows progress.
    private(set) var switching: Set<DisplayIdentity> = []
    var alert: String?
    private(set) var accessibilityGranted = Permissions.accessibility

    init() {
        displays = DisplayManager(engine: engine, profiles: profiles)
    }

    func start() {
        Preference.register()
        displays.onChange = { [weak self] in self?.displaysChanged() }
        displays.start()
        registerHotkeys()
        updateMediaKeys()

        NotificationCenter.default.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.displays.scheduleRefresh(after: .seconds(2)) }
        }
        NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.updateMediaKeys() }
        }
    }

    /// Hand the panels back to macOS before the virtual displays disappear.
    func prepareForTermination() {
        engine.disableAll()
        GammaDimmer.restoreAll()
    }

    // MARK: - Sharp mode

    func isSwitching(_ display: Display) -> Bool {
        switching.contains(display.identity)
    }

    func setSharp(_ enabled: Bool, for display: Display) async {
        profiles.update(display.identity) {
            $0.sharpMode = enabled
            $0.name = display.name
        }
        if enabled {
            switching.insert(display.identity)
            defer { switching.remove(display.identity) }
            do {
                try await engine.enable(display, resolution: profiles.profile(for: display.identity)?.sharpResolution)
            } catch {
                profiles.update(display.identity) { $0.sharpMode = false }
                alert = error.localizedDescription
            }
        } else {
            engine.disable(display.identity)
        }
        displays.refresh()
    }

    func sharpModes(for display: Display) -> [PointSize] {
        engine.modes(for: display.identity)
    }

    // MARK: - Resolution

    func resolutionChoices(for display: Display) -> [DisplayMode] {
        if display.isSharp {
            let refresh = display.current?.refreshRate ?? 0
            return sharpModes(for: display).reversed().map {
                DisplayMode(size: $0, pixels: $0.doubled, refreshRate: refresh)
            }
        }
        return ModeService.resolutionChoices(of: display.id)
    }

    func setResolution(_ mode: DisplayMode, for display: Display) {
        if display.isSharp {
            engine.setResolution(mode.size, for: display.identity)
            profiles.update(display.identity) { $0.sharpResolution = mode.size }
        } else if let match = ModeService.find(on: display.id, size: mode.size, hiDPI: mode.isHiDPI, refresh: display.current?.refreshRate) {
            ModeService.apply(match, to: display.id)
        }
        displays.refresh()
    }

    func refreshRates(for display: Display) -> [Double] {
        if display.isSharp {
            guard let native = ModeService.nativeMode(of: display.id) else { return [] }
            return ModeService.refreshRates(of: display.id, matching: DisplayMode(native))
        }
        guard let current = display.current else { return [] }
        return ModeService.refreshRates(of: display.id, matching: current)
    }

    func setRefreshRate(_ rate: Double, for display: Display) async {
        if display.isSharp {
            // The virtual display's refresh rate is fixed at creation: switch
            // the panel, then rebuild Sharp mode on top of it.
            engine.disable(display.identity)
            if let native = ModeService.nativeMode(of: display.id, preferredRefresh: rate) {
                ModeService.apply(native, to: display.id)
            }
            displays.refresh()
            if let updated = displays.display(for: display.identity) {
                await setSharp(true, for: updated)
            }
        } else if let current = display.current,
                  let match = ModeService.find(on: display.id, size: current.size, hiDPI: current.isHiDPI, refresh: rate) {
            ModeService.apply(match, to: display.id)
            displays.refresh()
        }
    }

    // MARK: - Arrangement

    func makeMain(_ display: Display) {
        ArrangementService.makeMain(display.desktopID)
        displays.refresh()
    }

    func mirror(_ display: Display, of master: Display?) {
        ArrangementService.mirror(display.id, of: master?.desktopID)
        displays.refresh()
    }

    // MARK: - Brightness

    func setBrightness(_ value: Double, for display: Display) {
        brightness.set(value, for: display)
        profiles.update(display.identity) { $0.brightness = value }
    }

    // MARK: - Permissions

    func refreshPermissions() {
        accessibilityGranted = Permissions.accessibility
        updateMediaKeys()
    }

    // MARK: - Private

    private func displaysChanged() {
        brightness.sync(displays.displays, panels: displays.panels, profiles: profiles)
        let autoSharp = Preference.bool(Preference.autoSharp)
        for display in displays.displays where !display.isBuiltin && !display.isSharp && !engine.isBusy(display.identity) {
            let saved = profiles.profile(for: display.identity)
            if saved?.sharpMode ?? (autoSharp && display.benefitsFromSharpMode) {
                Task { await setSharp(true, for: display) }
            }
        }
    }

    private func updateMediaKeys() {
        let wanted = Preference.bool(Preference.keyboardBrightness) || Preference.bool(Preference.keyboardVolume)
        if wanted, Permissions.accessibility {
            mediaKeys.handler = { [weak self] key, isDown, fine in
                self?.handleMediaKey(key, isDown: isDown, fine: fine) ?? false
            }
            mediaKeys.start()
        } else {
            mediaKeys.stop()
        }
    }

    private func displayUnderPointer() -> Display? {
        WindowMover.displayIDUnderPointer().flatMap(displays.display(withDesktopID:))
    }

    private func handleMediaKey(_ key: MediaKeyTap.Key, isDown: Bool, fine: Bool) -> Bool {
        guard let display = displayUnderPointer(), !display.isBuiltin else { return false }
        switch key {
        case .brightnessUp, .brightnessDown:
            guard Preference.bool(Preference.keyboardBrightness), brightness.canAdjust(display) else { return false }
            if isDown { stepBrightness(of: display, up: key == .brightnessUp, fine: fine) }
            return true
        case .volumeUp, .volumeDown, .mute:
            guard Preference.bool(Preference.keyboardVolume), let volume = brightness.volumes[display.identity] else { return false }
            if isDown {
                let value = key == .mute ? 0 : BrightnessStep.next(from: volume, up: key == .volumeUp, fine: fine)
                brightness.setVolume(value, for: display)
                HUD.shared.show(symbol: value == 0 ? "speaker.slash.fill" : "speaker.wave.2.fill", title: display.name, value: value, on: screen(of: display))
            }
            return true
        }
    }

    private func stepBrightness(of display: Display, up: Bool, fine: Bool) {
        let current = brightness.levels[display.identity] ?? 1
        let value = BrightnessStep.next(from: current, up: up, fine: fine)
        setBrightness(value, for: display)
        HUD.shared.show(symbol: value < 0.5 ? "sun.min.fill" : "sun.max.fill", title: display.name, value: value, on: screen(of: display))
    }

    private func screen(of display: Display) -> NSScreen? {
        NSScreen.screens.first { $0.displayID == display.desktopID }
    }

    private func registerHotkeys() {
        KeyboardShortcuts.onKeyDown(for: .moveWindowNext) { [weak self] in self?.moveWindow(1) }
        KeyboardShortcuts.onKeyDown(for: .moveWindowPrevious) { [weak self] in self?.moveWindow(-1) }
        KeyboardShortcuts.onKeyDown(for: .moveCursorNext) { WindowMover.moveCursor(direction: 1) }
        KeyboardShortcuts.onKeyDown(for: .toggleSharpMode) { [weak self] in self?.toggleSharpUnderPointer() }
        KeyboardShortcuts.onKeyDown(for: .sharpMoreSpace) { [weak self] in self?.stepSharpResolution(1) }
        KeyboardShortcuts.onKeyDown(for: .sharpLargerText) { [weak self] in self?.stepSharpResolution(-1) }
        KeyboardShortcuts.onKeyDown(for: .brightnessUpAll) { [weak self] in self?.stepAllBrightness(up: true) }
        KeyboardShortcuts.onKeyDown(for: .brightnessDownAll) { [weak self] in self?.stepAllBrightness(up: false) }
    }

    private func moveWindow(_ direction: Int) {
        if WindowMover.moveFocusedWindow(direction: direction) == .noPermission {
            Permissions.requestAccessibility()
        }
    }

    /// The external display under the pointer, or the first external one.
    private func targetExternal() -> Display? {
        if let display = displayUnderPointer(), !display.isBuiltin { return display }
        return displays.displays.first { !$0.isBuiltin }
    }

    private func toggleSharpUnderPointer() {
        guard let display = targetExternal(), !isSwitching(display) else { return }
        Task { await setSharp(!display.isSharp, for: display) }
    }

    private func stepSharpResolution(_ direction: Int) {
        guard let display = targetExternal(), display.isSharp, let current = display.current?.size,
              let next = HiDPIModeCatalog.step(from: current, by: direction, in: sharpModes(for: display)),
              next != current else { return }
        setResolution(DisplayMode(size: next, pixels: next.doubled, refreshRate: 0), for: display)
    }

    private func stepAllBrightness(up: Bool) {
        for display in displays.displays where brightness.canAdjust(display) {
            stepBrightness(of: display, up: up, fine: false)
        }
    }
}
