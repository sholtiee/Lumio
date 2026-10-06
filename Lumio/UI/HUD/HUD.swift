import AppKit
import Observation
import SwiftUI

/// A small level indicator in the corner of the affected display, styled like
/// the system brightness/volume indicator. Never takes focus or clicks.
@MainActor
final class HUD {
    static let shared = HUD()

    @Observable
    final class Model {
        var symbol = "sun.max.fill"
        var title = ""
        var value = 0.0
    }

    private let model = Model()
    private var panel: NSPanel?
    private var hideTask: Task<Void, Never>?
    private let size = CGSize(width: 260, height: 64)

    func show(symbol: String, title: String, value: Double, on screen: NSScreen?) {
        guard Preference.bool(Preference.showHUD), let screen = screen ?? NSScreen.main else { return }
        model.symbol = symbol
        model.title = title
        model.value = value

        let panel = panel ?? makePanel()
        self.panel = panel
        let visible = screen.visibleFrame
        panel.setFrameOrigin(CGPoint(x: visible.maxX - size.width - 12, y: visible.maxY - size.height - 12))
        if !panel.isVisible || panel.alphaValue < 1 {
            panel.alphaValue = 1
            panel.orderFrontRegardless()
        }

        hideTask?.cancel()
        hideTask = Task {
            try? await Task.sleep(for: .seconds(1.4))
            guard !Task.isCancelled else { return }
            NSAnimationContext.runAnimationGroup({ $0.duration = 0.25; panel.animator().alphaValue = 0 }) {
                Task { @MainActor in if panel.alphaValue == 0 { panel.orderOut(nil) } }
            }
        }
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: CGRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        panel.contentView = NSHostingView(rootView: HUDView(model: model))
        return panel
    }
}

private struct HUDView: View {
    let model: HUD.Model

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: model.symbol)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 24)
                .contentTransition(.symbolEffect(.replace))
            VStack(alignment: .leading, spacing: 6) {
                Text(model.title)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.quaternary)
                        Capsule().fill(.primary)
                            .frame(width: max(6, proxy.size.width * model.value))
                    }
                }
                .frame(height: 6)
                .animation(.snappy(duration: 0.15), value: model.value)
            }
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(.white.opacity(0.08)))
    }
}
