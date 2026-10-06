#if DEBUG
import AppKit
import SwiftUI

/// UI review without Screen Recording permission:
/// `LUMIO_SNAPSHOT_DIR=/tmp/shots Lumio.app/Contents/MacOS/Lumio`
/// renders the menu bar panel and every Settings pane, light and dark, then quits.
@MainActor
enum DebugSnapshots {
    static func runIfRequested(model: AppModel) {
        guard let path = ProcessInfo.processInfo.environment["LUMIO_SNAPSHOT_DIR"] else { return }
        let directory = URL(fileURLWithPath: path)
        Task {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try? await Task.sleep(for: .seconds(3)) // let displays and DDC probing settle
            var panes: [(String, SettingsView.Pane)] = [("general", .general), ("shortcuts", .shortcuts), ("about", .about)]
            for display in model.displays.displays {
                panes.append(("display-\(display.isBuiltin ? "builtin" : "external")", .display(display.identity)))
            }
            for (suffix, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
                await render(MenuBarPanel().environment(model), appearance: appearance, to: directory.appending(path: "panel-\(suffix).png"))
                for (name, pane) in panes {
                    await render(SettingsView(initial: pane).environment(model), appearance: appearance, to: directory.appending(path: "settings-\(name)-\(suffix).png"))
                }
            }
            NSApp.terminate(nil)
        }
    }

    private static func render(_ view: some View, appearance: NSAppearance.Name, to url: URL) async {
        let host = NSHostingView(rootView: view.background(Color(nsColor: .windowBackgroundColor)))
        host.appearance = NSAppearance(named: appearance)
        host.frame = CGRect(origin: .zero, size: host.fittingSize)
        let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.appearance = host.appearance
        window.backgroundColor = appearance == .darkAqua ? NSColor(white: 0.16, alpha: 1) : NSColor(white: 0.95, alpha: 1)
        window.contentView = host
        try? await Task.sleep(for: .milliseconds(600))
        host.layoutSubtreeIfNeeded()
        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return }
        host.cacheDisplay(in: host.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: url)
        window.close()
    }
}
#endif
