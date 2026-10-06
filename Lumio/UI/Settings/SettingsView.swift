import LumioKit
import SwiftUI

/// Settings laid out like System Settings: sidebar of panes, grouped forms.
struct SettingsView: View {
    enum Pane: Hashable {
        case general
        case display(DisplayIdentity)
        case shortcuts
        case about
    }

    @Environment(AppModel.self) private var model
    @State private var selection: Pane?

    init(initial: Pane = .general) {
        _selection = State(initialValue: initial)
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                SidebarRow(title: Text("General"), symbol: "gearshape.fill", color: .gray)
                    .tag(Pane.general)

                Section("Displays") {
                    ForEach(model.displays.displays) { display in
                        SidebarRow(title: Text(verbatim: display.name), symbol: display.symbolName, color: display.isSharp ? .accentColor : .blue)
                            .tag(Pane.display(display.identity))
                    }
                }

                Section {
                    SidebarRow(title: Text("Shortcuts"), symbol: "command", color: .purple)
                        .tag(Pane.shortcuts)
                    SidebarRow(title: Text("About Lumio"), symbol: "info", color: .gray)
                        .tag(Pane.about)
                }
            }
            .navigationSplitViewColumnWidth(210)
        } detail: {
            Group {
                switch selection {
                case .general, nil:
                    GeneralPane()
                case .display(let identity):
                    if let display = model.displays.display(for: identity) {
                        DisplayPane(display: display)
                    } else {
                        ContentUnavailableView("Display Disconnected", systemImage: "display.trianglebadge.exclamationmark")
                    }
                case .shortcuts:
                    ShortcutsPane()
                case .about:
                    AboutPane()
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.visible)
        }
        .frame(width: 740, height: 540)
        .task {
            // Settings can be opened from a menu bar app that is not active.
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}

/// Sidebar item with a coloured rounded-square icon, as in System Settings.
private struct SidebarRow: View {
    let title: Text
    let symbol: String
    let color: Color

    var body: some View {
        Label {
            title.lineLimit(1)
        } icon: {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(color.gradient, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
        }
    }
}
