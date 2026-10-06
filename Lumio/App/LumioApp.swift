import AppKit
import SwiftUI

@main
struct LumioApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarPanel()
                .environment(delegate.model)
        } label: {
            Image(systemName: "display")
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environment(delegate.model)
        }
        .windowResizability(.contentSize)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()
    private var signalSources: [DispatchSourceSignal] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        model.start()
        handleTerminationSignals()
    }

    func applicationWillTerminate(_ notification: Notification) {
        model.prepareForTermination()
    }

    /// `kill` and logout skip `applicationWillTerminate`. Route them through
    /// a normal quit so Sharp mode is always unwound.
    private func handleTerminationSignals() {
        for sig in [SIGTERM, SIGINT, SIGHUP] {
            signal(sig, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: sig, queue: .main)
            source.setEventHandler { NSApp.terminate(nil) }
            source.resume()
            signalSources.append(source)
        }
    }
}
