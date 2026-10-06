import Foundation
import LumioKit
import Observation

/// Per-display choices, persisted in UserDefaults as JSON.
@MainActor
@Observable
final class ProfileStore {
    private(set) var book: ProfileBook
    @ObservationIgnored private let defaults: UserDefaults
    private static let key = "profiles.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        book = defaults.data(forKey: Self.key).flatMap { try? JSONDecoder().decode(ProfileBook.self, from: $0) } ?? ProfileBook()
    }

    func profile(for identity: DisplayIdentity) -> DisplayProfile? {
        book.profile(for: identity)
    }

    func update(_ identity: DisplayIdentity, _ change: (inout DisplayProfile) -> Void) {
        var updated = book
        updated.update(identity, change)
        guard updated != book else { return }
        book = updated
        if let data = try? JSONEncoder().encode(book) {
            defaults.set(data, forKey: Self.key)
        }
    }
}

/// App-wide settings, shared between SwiftUI (`@AppStorage`) and services.
enum Preference {
    static let autoSharp = "autoSharpForNewDisplays"
    static let keyboardBrightness = "keyboardControlsExternalBrightness"
    static let keyboardVolume = "keyboardControlsExternalVolume"
    static let showHUD = "showHUD"

    static func register() {
        UserDefaults.standard.register(defaults: [
            autoSharp: false,
            keyboardBrightness: true,
            keyboardVolume: false,
            showHUD: true,
        ])
    }

    static func bool(_ key: String) -> Bool {
        UserDefaults.standard.bool(forKey: key)
    }
}
