import CoreGraphics
import Foundation

/// Built-in panel brightness via the private DisplayServices framework —
/// the same call the brightness keys and Control Center use.
enum BuiltinBrightness {
    private typealias Getter = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private typealias Setter = @convention(c) (CGDirectDisplayID, Float) -> Int32

    nonisolated(unsafe) private static let handle = dlopen(
        "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_LAZY
    )
    private static let getter: Getter? = symbol("DisplayServicesGetBrightness")
    private static let setter: Setter? = symbol("DisplayServicesSetBrightness")

    static func get(_ id: CGDirectDisplayID) -> Double? {
        var value: Float = 0
        guard let getter, getter(id, &value) == 0 else { return nil }
        return Double(value)
    }

    @discardableResult
    static func set(_ id: CGDirectDisplayID, _ value: Double) -> Bool {
        setter?(id, Float(value)) == 0
    }

    private static func symbol<T>(_ name: String) -> T? {
        guard let handle, let pointer = dlsym(handle, name) else { return nil }
        return unsafeBitCast(pointer, to: T.self)
    }
}

/// Software dimming for panels without DDC: scales the display's own gamma
/// table, so calibration is preserved and 100% is exactly the original.
@MainActor
enum GammaDimmer {
    private struct Table {
        var red: [CGGammaValue]
        var green: [CGGammaValue]
        var blue: [CGGammaValue]
    }

    private static var originals: [CGDirectDisplayID: Table] = [:]

    static func set(_ id: CGDirectDisplayID, _ value: Double) {
        guard let original = originals[id] ?? capture(id) else { return }
        originals[id] = original
        let factor = CGGammaValue(max(value, 0.05))
        var red = original.red.map { $0 * factor }
        var green = original.green.map { $0 * factor }
        var blue = original.blue.map { $0 * factor }
        CGSetDisplayTransferByTable(id, UInt32(red.count), &red, &green, &blue)
    }

    /// Undo all dimming — on quit, and when a display goes away.
    static func restoreAll() {
        guard !originals.isEmpty else { return }
        originals.removeAll()
        CGDisplayRestoreColorSyncSettings()
    }

    private static func capture(_ id: CGDirectDisplayID) -> Table? {
        let capacity = CGDisplayGammaTableCapacity(id)
        guard capacity > 0 else { return nil }
        var red = [CGGammaValue](repeating: 0, count: Int(capacity))
        var green = red, blue = red
        var count: UInt32 = 0
        guard CGGetDisplayTransferByTable(id, capacity, &red, &green, &blue, &count) == .success, count > 0 else { return nil }
        let n = Int(count)
        return Table(red: Array(red.prefix(n)), green: Array(green.prefix(n)), blue: Array(blue.prefix(n)))
    }
}
