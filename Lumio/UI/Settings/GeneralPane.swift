import SwiftUI

struct GeneralPane: View {
    @Environment(AppModel.self) private var model
    @AppStorage(Preference.autoSharp) private var autoSharp = false
    @AppStorage(Preference.keyboardBrightness) private var keyboardBrightness = true
    @AppStorage(Preference.keyboardVolume) private var keyboardVolume = false
    @AppStorage(Preference.showHUD) private var showHUD = true
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var launchError: String?

    var body: some View {
        Form {
            Section {
                Toggle("Open Lumio at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        do {
                            try LaunchAtLogin.set(enabled)
                        } catch {
                            launchError = error.localizedDescription
                            launchAtLogin = LaunchAtLogin.isEnabled
                        }
                    }
            } footer: {
                if let launchError {
                    Text(launchError).foregroundStyle(.red)
                } else {
                    Text("Sharp mode needs Lumio running, so it is best to keep this on.")
                }
            }

            Section {
                Toggle("Turn on Sharp text for new non‑Retina displays", isOn: $autoSharp)
            } header: {
                Text("Sharp Text")
            } footer: {
                Text("Lumio remembers your choice for each display and restores it whenever the display is connected.")
            }

            Section {
                Toggle("Brightness keys adjust the display under the pointer", isOn: $keyboardBrightness)
                Toggle("Volume keys adjust the monitor's speakers", isOn: $keyboardVolume)
                Toggle("Show indicator when brightness changes", isOn: $showHUD)
                AccessibilityStatusRow()
            } header: {
                Text("Keyboard")
            } footer: {
                Text("The built-in display and speakers keep working as usual. Hold ⌥⇧ for finer steps.")
            }
        }
    }
}

/// Live Accessibility status, re-checked while visible — macOS has no
/// notification for the user flipping the switch.
struct AccessibilityStatusRow: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack {
            if model.accessibilityGranted {
                Label("Accessibility access granted", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Label("Accessibility access is needed for media keys and moving windows", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Spacer()
                Button("Allow…") {
                    Permissions.requestAccessibility()
                    Permissions.openAccessibilitySettings()
                }
            }
        }
        .task {
            while !Task.isCancelled {
                model.refreshPermissions()
                try? await Task.sleep(for: .seconds(1.5))
            }
        }
    }
}
