import SwiftUI

struct DisplayCard: View {
    let display: Display
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                DisplayBadge(display: display)
                VStack(alignment: .leading, spacing: 1) {
                    Text(display.name)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    Text(display.summary)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                DisplayOptionsMenu(display: display)
            }

            if model.brightness.canAdjust(display) {
                BrightnessSlider(display: display)
            }

            if !display.isBuiltin {
                SharpModeRow(display: display)
            }
        }
        .padding(10)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

/// Round icon that lights up in the accent colour when Sharp mode is on,
/// like an active Control Center toggle.
struct DisplayBadge: View {
    let display: Display
    var size: CGFloat = 30

    var body: some View {
        Image(systemName: display.symbolName)
            .font(.system(size: size * 0.45, weight: .medium))
            .foregroundStyle(display.isSharp ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
            .frame(width: size, height: size)
            .background(
                Circle().fill(display.isSharp ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.quaternary))
            )
            .animation(.smooth(duration: 0.2), value: display.isSharp)
    }
}

struct BrightnessSlider: View {
    let display: Display
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "sun.min.fill")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            Slider(value: Binding(
                get: { model.brightness.levels[display.identity] ?? 1 },
                set: { model.setBrightness($0, for: display) }
            ))
            .controlSize(.small)
            Image(systemName: "sun.max.fill")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .help(model.brightness.usesHardware(display)
            ? String(localized: "Brightness")
            : String(localized: "Software dimming — this monitor does not accept DDC/CI commands"))
    }
}

struct SharpModeRow: View {
    let display: Display
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text("Sharp text")
                    .font(.system(size: 12, weight: .medium))
                Text(caption)
                    .font(.system(size: 11))
                    .foregroundStyle(display.benefitsFromSharpMode && !display.isSharp ? AnyShapeStyle(.orange) : AnyShapeStyle(.secondary))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 4)
            if model.isSwitching(display) {
                ProgressView().controlSize(.small)
            }
            Toggle("Sharp text", isOn: Binding(
                get: { display.isSharp || model.isSwitching(display) },
                set: { enabled in Task { await model.setSharp(enabled, for: display) } }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)
            .disabled(model.isSwitching(display))
        }
        .help("Renders the desktop at 2× (HiDPI) and scales it to the panel, like a Retina display.")
    }

    private var caption: String {
        if model.isSwitching(display) { return String(localized: "Switching…") }
        if display.isSharp { return String(localized: "Rendering at 2× — HiDPI") }
        if display.benefitsFromSharpMode { return String(localized: "Text looks soft on this display") }
        return String(localized: "Off")
    }
}

/// "…" menu: resolution, refresh rate, main display.
struct DisplayOptionsMenu: View {
    let display: Display
    @Environment(AppModel.self) private var model

    var body: some View {
        Menu {
            Picker("Resolution", selection: resolution) {
                ForEach(model.resolutionChoices(for: display)) { mode in
                    Text(display.label(for: mode)).tag(Optional(mode.choiceKey))
                }
            }
            .pickerStyle(.inline)

            let rates = model.refreshRates(for: display)
            if rates.count > 1 {
                Picker("Refresh Rate", selection: refreshRate) {
                    ForEach(rates, id: \.self) { rate in
                        Text("\(Int(rate)) Hz").tag(Optional(rate))
                    }
                }
                .pickerStyle(.inline)
            }

            if model.displays.displays.count > 1 {
                Divider()
                Button("Use as Main Display") { model.makeMain(display) }
                    .disabled(display.isMain)
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 24, height: 24)
                .contentShape(Circle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Resolution and refresh rate")
    }

    private var resolution: Binding<String?> {
        Binding(
            get: { display.current?.choiceKey },
            set: { key in
                guard let mode = model.resolutionChoices(for: display).first(where: { $0.choiceKey == key }) else { return }
                model.setResolution(mode, for: display)
            }
        )
    }

    private var refreshRate: Binding<Double?> {
        Binding(
            get: { (display.isSharp ? display.output : display.current)?.refreshRate.rounded() },
            set: { rate in
                guard let rate else { return }
                Task { await model.setRefreshRate(rate, for: display) }
            }
        )
    }
}

extension DisplayMode {
    /// Identity for pickers: size and scale, not refresh rate.
    var choiceKey: String { "\(size.width)x\(size.height)/\(isHiDPI ? 2 : 1)" }
}

extension Display {
    /// "2560 × 1440 · 144 Hz", with "Sharp" when rendering at 2×.
    var summary: String {
        guard let current else { return "" }
        var parts = [current.size.description]
        if let rate = (isSharp ? output : current)?.refreshLabel, !rate.isEmpty { parts.append(rate) }
        if isSharp { parts.append(String(localized: "Sharp")) }
        return parts.joined(separator: " · ")
    }

    func label(for mode: DisplayMode) -> String {
        var text = mode.size.description
        if isSharp {
            if mode.size == nativePixels { text += " — " + String(localized: "1:1, sharpest") }
        } else if mode.isHiDPI {
            text += " (HiDPI)"
        } else if mode.size == nativePixels {
            text += " — " + String(localized: "native")
        }
        return text
    }
}
