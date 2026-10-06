import SwiftUI

/// The menu bar window: one Control Center–style card per display.
struct MenuBarPanel: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Displays")
                .font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, 4)
                .padding(.top, 2)

            ForEach(model.displays.displays) { display in
                DisplayCard(display: display)
            }

            if !model.displays.displays.contains(where: { !$0.isBuiltin }) {
                NoExternalDisplayCard()
            }

            if let alert = model.alert {
                AlertCard(message: alert) { model.alert = nil }
            }

            Divider()
                .padding(.horizontal, 4)
                .padding(.vertical, 2)

            VStack(spacing: 0) {
                MenuRow(title: "Settings…", shortcut: "⌘,") {
                    NSApp.activate(ignoringOtherApps: true)
                    openSettings()
                }
                .keyboardShortcut(",")
                MenuRow(title: "Quit Lumio", shortcut: "⌘Q") {
                    NSApp.terminate(nil)
                }
                .keyboardShortcut("q")
            }
        }
        .padding(10)
        .frame(width: 330)
        .onAppear {
            model.brightness.reloadBuiltin(model.displays.displays)
            model.refreshPermissions()
        }
    }
}

private struct NoExternalDisplayCard: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "cable.connector.horizontal")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .frame(width: 30, height: 30)
            Text("Connect an external display to adjust it here.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct AlertCard: View {
    let message: String
    let dismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.system(size: 11))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

/// A row that looks and behaves like a native menu item.
struct MenuRow: View {
    let title: LocalizedStringKey
    var shortcut: String?
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                Spacer()
                if let shortcut {
                    Text(shortcut).foregroundStyle(hovering ? .white.opacity(0.85) : .secondary)
                }
            }
            .font(.system(size: 13))
            .foregroundStyle(hovering ? .white : .primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(hovering ? Color.accentColor : .clear, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}
