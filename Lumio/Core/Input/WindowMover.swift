import AppKit
import ApplicationServices
import LumioKit

/// Moves the focused window, or the pointer, between screens.
@MainActor
enum WindowMover {
    /// Screens in left-to-right order, with frames in top-left (AX/CG) coordinates.
    private struct Layout {
        let screens: [NSScreen]
        let frames: [CGRect]
        let visibleFrames: [CGRect]
        let order: [Int]

        init?() {
            let screens = NSScreen.screens
            guard screens.count > 1, let primary = screens.first else { return nil }
            let height = primary.frame.height
            self.screens = screens
            frames = screens.map { ScreenGeometry.flip($0.frame, primaryHeight: height) }
            visibleFrames = screens.map { ScreenGeometry.flip($0.visibleFrame, primaryHeight: height) }
            order = ScreenGeometry.spatialOrder(frames)
        }

        func neighbour(of index: Int, direction: Int) -> Int {
            let position = order.firstIndex(of: index) ?? 0
            return order[ScreenGeometry.neighbour(of: position, count: order.count, direction: direction)]
        }
    }

    enum Outcome {
        case moved, noPermission, nothingToMove
    }

    static func moveFocusedWindow(direction: Int) -> Outcome {
        guard Permissions.accessibility else { return .noPermission }
        guard let layout = Layout(),
              let app = NSWorkspace.shared.frontmostApplication,
              let window = element(AXUIElementCreateApplication(app.processIdentifier), kAXFocusedWindowAttribute),
              bool(window, "AXFullScreen") != true,
              let frame = frame(of: window),
              let current = ScreenGeometry.bestMatch(for: frame, in: layout.frames) else { return .nothingToMove }

        let target = layout.neighbour(of: current, direction: direction)
        let mapped = ScreenGeometry.map(frame, from: layout.visibleFrames[current], to: layout.visibleFrames[target])
        // Position first so the new size is not clamped by the old screen, then
        // position again in case the app adjusted its size.
        setPosition(window, mapped.origin)
        setSize(window, mapped.size)
        setPosition(window, mapped.origin)
        return .moved
    }

    static func moveCursor(direction: Int) {
        guard let layout = Layout() else { return }
        let mouse = NSEvent.mouseLocation
        let current = layout.screens.firstIndex { NSMouseInRect(mouse, $0.frame, false) } ?? 0
        let target = layout.frames[layout.neighbour(of: current, direction: direction)]
        CGWarpMouseCursorPosition(CGPoint(x: target.midX, y: target.midY))
        CGAssociateMouseAndMouseCursorPosition(1)
    }

    /// The display whose screen contains the pointer.
    static func displayIDUnderPointer() -> CGDirectDisplayID? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }?.displayID
    }

    // MARK: - AX helpers

    private static func value(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value
    }

    private static func element(_ element: AXUIElement, _ attribute: String) -> AXUIElement? {
        guard let value = value(element, attribute), CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return unsafeDowncast(value, to: AXUIElement.self)
    }

    private static func bool(_ element: AXUIElement, _ attribute: String) -> Bool? {
        value(element, attribute) as? Bool
    }

    private static func frame(of window: AXUIElement) -> CGRect? {
        guard let position = value(window, kAXPositionAttribute), let size = value(window, kAXSizeAttribute),
              CFGetTypeID(position) == AXValueGetTypeID(), CFGetTypeID(size) == AXValueGetTypeID() else { return nil }
        var origin = CGPoint.zero
        var extent = CGSize.zero
        guard AXValueGetValue(unsafeDowncast(position, to: AXValue.self), .cgPoint, &origin),
              AXValueGetValue(unsafeDowncast(size, to: AXValue.self), .cgSize, &extent) else { return nil }
        return CGRect(origin: origin, size: extent)
    }

    private static func setPosition(_ window: AXUIElement, _ point: CGPoint) {
        var point = point
        if let value = AXValueCreate(.cgPoint, &point) {
            AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, value)
        }
    }

    private static func setSize(_ window: AXUIElement, _ size: CGSize) {
        var size = size
        if let value = AXValueCreate(.cgSize, &size) {
            AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, value)
        }
    }
}
