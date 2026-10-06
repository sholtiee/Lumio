import Foundation

/// Stable identity of a physical display, taken from its EDID.
/// `CGDirectDisplayID` changes across reconnects; this does not.
public struct DisplayIdentity: Hashable, Codable, Sendable {
    public var vendor: UInt32
    public var model: UInt32
    public var serial: UInt32

    public init(vendor: UInt32, model: UInt32, serial: UInt32) {
        self.vendor = vendor
        self.model = model
        self.serial = serial
    }

    public var key: String { String(format: "%04X-%04X-%08X", vendor, model, serial) }

    /// Serial for the virtual display that stands in for this one. Stable, so
    /// macOS remembers its arrangement between sessions; never zero.
    public var virtualSerial: UInt32 {
        let mixed = (vendor &<< 16) ^ model ^ serial.byteSwapped
        return mixed == 0 ? 1 : mixed
    }
}

/// What the user chose for a display. Missing values mean "leave macOS alone".
public struct DisplayProfile: Codable, Sendable, Equatable {
    public var name: String?
    public var sharpMode: Bool
    public var sharpResolution: PointSize?
    public var brightness: Double?

    public init(name: String? = nil, sharpMode: Bool = false, sharpResolution: PointSize? = nil, brightness: Double? = nil) {
        self.name = name
        self.sharpMode = sharpMode
        self.sharpResolution = sharpResolution
        self.brightness = brightness
    }
}

/// All saved profiles, keyed by `DisplayIdentity.key`.
public struct ProfileBook: Codable, Sendable, Equatable {
    public var profiles: [String: DisplayProfile]

    public init(profiles: [String: DisplayProfile] = [:]) {
        self.profiles = profiles
    }

    /// Exact match first. Otherwise, if exactly one saved profile has the same
    /// vendor and model, use it — many monitors report serial 0 or change it
    /// between ports.
    public func profile(for identity: DisplayIdentity) -> DisplayProfile? {
        if let exact = profiles[identity.key] { return exact }
        let prefix = String(format: "%04X-%04X-", identity.vendor, identity.model)
        let sameModel = profiles.filter { $0.key.hasPrefix(prefix) }
        return sameModel.count == 1 ? sameModel.first?.value : nil
    }

    public mutating func update(_ identity: DisplayIdentity, _ change: (inout DisplayProfile) -> Void) {
        var profile = profile(for: identity) ?? DisplayProfile()
        change(&profile)
        profiles[identity.key] = profile
    }
}
