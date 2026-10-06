import LumioKit
import SwiftUI

struct DisplayPane: View {
    let display: Display
    @Environment(AppModel.self) private var model

    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    DisplayBadge(display: display, size: 52)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(display.name).font(.title3.weight(.semibold))
                        Text(display.facts).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            if !display.isBuiltin {
                Section {
                    LabeledContent {
                        HStack {
                            if model.isSwitching(display) { ProgressView().controlSize(.small) }
                            Toggle("Sharp text", isOn: Binding(
                                get: { display.isSharp || model.isSwitching(display) },
                                set: { enabled in Task { await model.setSharp(enabled, for: display) } }
                            ))
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .disabled(model.isSwitching(display))
                        }
                    } label: {
                        Text("Sharp text")
                        Text("Renders the desktop at 2× and scales it to the panel's native pixels, like a Retina display.")
                    }
                } footer: {
                    if display.isSharp {
                        Text("While Sharp text is on, HDR and variable refresh rate are not available on this display.")
                    }
                }
            }

            Section("Display") {
                Picker("Resolution", selection: resolution) {
                    ForEach(model.resolutionChoices(for: display)) { mode in
                        Text(display.label(for: mode)).tag(Optional(mode.choiceKey))
                    }
                }

                let rates = model.refreshRates(for: display)
                if !rates.isEmpty {
                    Picker("Refresh rate", selection: refreshRate) {
                        ForEach(rates, id: \.self) { Text("\(Int($0)) Hz").tag(Optional($0)) }
                    }
                }

                if model.displays.displays.count > 1 {
                    LabeledContent("Main display") {
                        if display.isMain {
                            Text("This display").foregroundStyle(.secondary)
                        } else {
                            Button("Use as Main") { model.makeMain(display) }
                        }
                    }

                    if !display.isSharp {
                        Picker("Mirror", selection: mirror) {
                            Text("Off").tag(CGDirectDisplayID?.none)
                            ForEach(model.displays.displays.filter { $0.id != display.id }) { other in
                                Text(other.name).tag(Optional(other.desktopID))
                            }
                        }
                    }
                }
            }

            if model.brightness.canAdjust(display) {
                Section {
                    LabeledContent("Brightness") { BrightnessSlider(display: display) }
                    if model.brightness.volumes[display.identity] != nil {
                        LabeledContent("Speaker volume") {
                            Slider(value: Binding(
                                get: { model.brightness.volumes[display.identity] ?? 0 },
                                set: { model.brightness.setVolume($0, for: display) }
                            ))
                        }
                    }
                } header: {
                    Text("Brightness")
                } footer: {
                    Text(brightnessFootnote)
                }
            }

            DiagnosticsSection(display: display)
        }
    }

    private var brightnessFootnote: String {
        switch model.brightness.methods[display.identity] {
        case .ddc: String(localized: "Adjusts the monitor's backlight over DDC/CI.")
        case .software: String(localized: "This monitor does not accept DDC/CI commands, so Lumio dims the image instead. The backlight stays the same.")
        default: ""
        }
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

    private var mirror: Binding<CGDirectDisplayID?> {
        Binding(
            get: { display.mirrorsDisplay },
            set: { master in
                model.mirror(display, of: master.flatMap { model.displays.display(withDesktopID: $0) })
            }
        )
    }
}

/// Answers "why does this look blurry?" with facts and a plain verdict.
private struct DiagnosticsSection: View {
    let display: Display
    @Environment(AppModel.self) private var model

    var body: some View {
        Section("Diagnostics") {
            LabeledContent("Verdict") {
                Text(verdict)
                    .multilineTextAlignment(.trailing)
                    .fixedSize(horizontal: false, vertical: true)
            }
            LabeledContent("Connection", value: display.isBuiltin ? String(localized: "Built-in") : String(localized: "External"))
            LabeledContent("Panel", value: display.nativePixels.description)
            if let current = display.current {
                LabeledContent("Desktop looks like", value: current.size.description)
                LabeledContent("Rendered at", value: "\(current.pixels.description) (\(current.isHiDPI ? "2×" : "1×"))")
            }
            if let output = display.output {
                LabeledContent("Signal", value: "\(output.pixels.description) · \(output.refreshLabel)")
            }
            if let ppi = display.pixelsPerInch {
                LabeledContent("Pixel density", value: "\(Int(ppi.rounded())) ppi")
            }
            LabeledContent("DDC/CI", value: ddcStatus)
            LabeledContent("ID", value: display.identity.key)
                .textSelection(.enabled)
        }
    }

    private var ddcStatus: String {
        switch model.brightness.methods[display.identity] {
        case .builtin: String(localized: "Not needed")
        case .ddc: String(localized: "Supported")
        case .software: String(localized: "Not available")
        case .probing: String(localized: "Checking…")
        case nil: "—"
        }
    }

    private var verdict: String {
        if display.isBuiltin {
            return String(localized: "Retina panel — macOS renders it at full sharpness.")
        }
        if display.isSharp {
            return String(localized: "Sharp text is on: the desktop renders at 2× and is scaled to the panel's native pixels.")
        }
        if let output = display.output, output.pixels != display.nativePixels {
            return String(localized: "The signal is not at the panel's native resolution, so the monitor upscales it and text looks blurry.")
        }
        if display.hasUsefulHiDPI {
            return display.current?.isHiDPI == true
                ? String(localized: "macOS renders this display in HiDPI. Nothing to fix.")
                : String(localized: "This display supports HiDPI but a 1× resolution is selected. Choose a HiDPI resolution.")
        }
        return String(localized: "macOS renders this display at 1×, so text looks soft. Turn on Sharp text.")
    }
}

extension Display {
    /// "27″ · 2560 × 1440 · 109 ppi"
    var facts: String {
        var parts: [String] = []
        if physicalSizeMM.width > 0 {
            let inches = (physicalSizeMM.width * physicalSizeMM.width + physicalSizeMM.height * physicalSizeMM.height).squareRoot() / 25.4
            parts.append("\(Int(inches.rounded()))″")
        }
        parts.append(nativePixels.description)
        if let ppi = pixelsPerInch { parts.append("\(Int(ppi.rounded())) ppi") }
        return parts.joined(separator: " · ")
    }
}
