import CoreGraphics
import LumioKit
import Observation

/// One brightness (and, where available, volume) control per display,
/// whatever the hardware path: DisplayServices for the built-in panel, DDC/CI
/// for monitors that support it, gamma dimming for the rest.
@MainActor
@Observable
final class BrightnessController {
    enum Method: Equatable {
        case probing
        case builtin
        case ddc(max: UInt16)
        case software
    }

    private(set) var methods: [DisplayIdentity: Method] = [:]
    private(set) var levels: [DisplayIdentity: Double] = [:]
    private(set) var volumes: [DisplayIdentity: Double] = [:]

    @ObservationIgnored private var channels: [DisplayIdentity: DDCChannel] = [:]
    @ObservationIgnored private var volumeMax: [DisplayIdentity: UInt16] = [:]

    func sync(_ displays: [Display], panels: [DisplayRegistry.Panel], profiles: ProfileStore) {
        let present = Set(displays.map(\.identity))
        for identity in methods.keys where !present.contains(identity) {
            methods[identity] = nil
            levels[identity] = nil
            volumes[identity] = nil
            channels[identity] = nil
        }

        for display in displays {
            let identity = display.identity
            if methods[identity] == .software, let level = levels[identity], level < 1 {
                GammaDimmer.set(display.id, level) // macOS resets gamma on every reconfiguration
            }
            guard methods[identity] == nil else { continue }

            if display.isBuiltin {
                if let level = BuiltinBrightness.get(display.id) {
                    methods[identity] = .builtin
                    levels[identity] = level
                }
            } else if let service = DisplayRegistry.match(identity, in: panels)?.service {
                let channel = DDCChannel(service: service)
                channels[identity] = channel
                methods[identity] = .probing
                let saved = profiles.profile(for: identity)?.brightness
                Task { await probe(display, channel: channel, saved: saved) }
            } else {
                useSoftware(display, saved: profiles.profile(for: identity)?.brightness)
            }
        }
    }

    /// The built-in level also changes through the keyboard and Control Center.
    func reloadBuiltin(_ displays: [Display]) {
        for display in displays where methods[display.identity] == .builtin {
            levels[display.identity] = BuiltinBrightness.get(display.id)
        }
    }

    func canAdjust(_ display: Display) -> Bool {
        switch methods[display.identity] {
        case .builtin, .ddc, .software: true
        case .probing, nil: false
        }
    }

    func usesHardware(_ display: Display) -> Bool {
        if case .ddc = methods[display.identity] { return true }
        return methods[display.identity] == .builtin
    }

    func set(_ value: Double, for display: Display) {
        let value = min(max(value, 0), 1)
        levels[display.identity] = value
        switch methods[display.identity] {
        case .builtin: BuiltinBrightness.set(display.id, value)
        case .ddc(let max): channels[display.identity]?.write(.brightness, UInt16((value * Double(max)).rounded()))
        case .software: GammaDimmer.set(display.id, value)
        case .probing, nil: break
        }
    }

    func setVolume(_ value: Double, for display: Display) {
        guard let max = volumeMax[display.identity] else { return }
        let value = min(Swift.max(value, 0), 1)
        volumes[display.identity] = value
        channels[display.identity]?.write(.volume, UInt16((value * Double(max)).rounded()))
    }

    private func probe(_ display: Display, channel: DDCChannel, saved: Double?) async {
        if let reply = await channel.read(.brightness) {
            methods[display.identity] = .ddc(max: reply.max)
            levels[display.identity] = Double(reply.current) / Double(reply.max)
            if let volume = await channel.read(.volume) {
                volumeMax[display.identity] = volume.max
                volumes[display.identity] = Double(volume.current) / Double(volume.max)
            }
        } else {
            channels[display.identity] = nil
            useSoftware(display, saved: saved)
        }
    }

    private func useSoftware(_ display: Display, saved: Double?) {
        methods[display.identity] = .software
        let level = saved ?? 1
        levels[display.identity] = level
        if level < 1 { GammaDimmer.set(display.id, level) }
    }
}
