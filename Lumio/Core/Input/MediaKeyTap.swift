import AppKit
import CoreGraphics

/// Intercepts the brightness and volume keys so they can drive the external
/// display under the pointer. Keys for the built-in panel pass through to
/// macOS untouched. Requires Accessibility.
@MainActor
final class MediaKeyTap {
    enum Key {
        case brightnessUp, brightnessDown, volumeUp, volumeDown, mute
    }

    /// Returns true when Lumio handled the key and macOS should not see it.
    /// Called for key-up too (`isDown == false`) so both halves are swallowed together.
    var handler: ((_ key: Key, _ isDown: Bool, _ fine: Bool) -> Bool)?

    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    fileprivate static weak var current: MediaKeyTap?

    var isRunning: Bool { tap != nil }

    @discardableResult
    func start() -> Bool {
        guard tap == nil else { return true }
        Self.current = self
        let mask = CGEventMask(1) << CGEventMask(NSEvent.EventType.systemDefined.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: mediaKeyCallback,
            userInfo: nil
        ) else { return false }
        self.tap = tap
        source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil
        source = nil
    }

    fileprivate func reenable() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
    }

    fileprivate func handle(_ event: CGEvent) -> Bool {
        // NX_SYSDEFINED, subtype 8 = auxiliary control buttons.
        guard let nsEvent = NSEvent(cgEvent: event), nsEvent.subtype.rawValue == 8 else { return false }
        let data = nsEvent.data1
        let keyFlags = data & 0xFFFF
        let isDown = (keyFlags & 0xFF00) >> 8 == 0x0A
        let key: Key
        switch (data & 0xFFFF_0000) >> 16 {
        case 0: key = .volumeUp      // NX_KEYTYPE_SOUND_UP
        case 1: key = .volumeDown    // NX_KEYTYPE_SOUND_DOWN
        case 2: key = .brightnessUp  // NX_KEYTYPE_BRIGHTNESS_UP
        case 3: key = .brightnessDown
        case 7: key = .mute
        default: return false
        }
        let fine = nsEvent.modifierFlags.isSuperset(of: [.option, .shift])
        return handler?(key, isDown, fine) ?? false
    }
}

private func mediaKeyCallback(
    proxy _: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon _: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    // The tap's run loop source is on the main run loop.
    nonisolated(unsafe) let event = event
    let consumed = MainActor.assumeIsolated {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            MediaKeyTap.current?.reenable()
            return false
        }
        return MediaKeyTap.current?.handle(event) == true
    }
    return consumed ? nil : Unmanaged.passUnretained(event)
}
