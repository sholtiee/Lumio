import KeyboardShortcuts
import SwiftUI

struct ShortcutsPane: View {
    @Environment(AppModel.self) private var model

    private var sections: [(title: String, hotkeys: [Hotkey])] {
        var result: [(String, [Hotkey])] = []
        for hotkey in Hotkey.allCases {
            if let index = result.firstIndex(where: { $0.0 == hotkey.section }) {
                result[index].1.append(hotkey)
            } else {
                result.append((hotkey.section, [hotkey]))
            }
        }
        return result
    }

    var body: some View {
        Form {
            ForEach(sections, id: \.title) { section in
                Section(section.title) {
                    ForEach(section.hotkeys) { hotkey in
                        KeyboardShortcuts.Recorder(hotkey.title, name: hotkey.name)
                    }
                }
            }
            if !model.accessibilityGranted {
                Section {
                    AccessibilityStatusRow()
                }
            }
        }
    }
}

struct AboutPane: View {
    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "–"
        let build = info?["CFBundleVersion"] as? String ?? "–"
        return "\(short) (\(build))"
    }

    var body: some View {
        VStack(spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
            VStack(spacing: 4) {
                Text("Lumio").font(.title.weight(.semibold))
                Text("Version \(version)").foregroundStyle(.secondary)
            }
            Text("Crisp text and simple control for every display on your Mac.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 340)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
