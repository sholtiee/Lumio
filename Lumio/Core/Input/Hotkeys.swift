import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let moveWindowNext = Self("moveWindowNext", default: .init(.rightArrow, modifiers: [.control, .option, .command]))
    static let moveWindowPrevious = Self("moveWindowPrevious", default: .init(.leftArrow, modifiers: [.control, .option, .command]))
    static let moveCursorNext = Self("moveCursorNext")
    static let toggleSharpMode = Self("toggleSharpMode")
    static let sharpMoreSpace = Self("sharpMoreSpace")
    static let sharpLargerText = Self("sharpLargerText")
    static let brightnessUpAll = Self("brightnessUpAll")
    static let brightnessDownAll = Self("brightnessDownAll")
}

/// Every global shortcut, in the order shown in Settings.
enum Hotkey: CaseIterable, Identifiable {
    case moveWindowNext, moveWindowPrevious, moveCursorNext
    case toggleSharpMode, sharpMoreSpace, sharpLargerText
    case brightnessUpAll, brightnessDownAll

    var id: Self { self }

    var name: KeyboardShortcuts.Name {
        switch self {
        case .moveWindowNext: .moveWindowNext
        case .moveWindowPrevious: .moveWindowPrevious
        case .moveCursorNext: .moveCursorNext
        case .toggleSharpMode: .toggleSharpMode
        case .sharpMoreSpace: .sharpMoreSpace
        case .sharpLargerText: .sharpLargerText
        case .brightnessUpAll: .brightnessUpAll
        case .brightnessDownAll: .brightnessDownAll
        }
    }

    var title: String {
        switch self {
        case .moveWindowNext: String(localized: "Move window to next display")
        case .moveWindowPrevious: String(localized: "Move window to previous display")
        case .moveCursorNext: String(localized: "Move pointer to next display")
        case .toggleSharpMode: String(localized: "Toggle Sharp mode")
        case .sharpMoreSpace: String(localized: "More space")
        case .sharpLargerText: String(localized: "Larger text")
        case .brightnessUpAll: String(localized: "Brighten all displays")
        case .brightnessDownAll: String(localized: "Dim all displays")
        }
    }

    var section: String {
        switch self {
        case .moveWindowNext, .moveWindowPrevious, .moveCursorNext: String(localized: "Windows")
        case .toggleSharpMode, .sharpMoreSpace, .sharpLargerText: String(localized: "Display under the pointer")
        case .brightnessUpAll, .brightnessDownAll: String(localized: "Brightness")
        }
    }
}
