import Foundation

/// Decides which "looks like" resolutions Sharp mode offers for a panel.
///
/// Every mode is rendered at 2× on a virtual display and downsampled by
/// WindowServer onto the physical panel, so each entry costs a framebuffer of
/// twice its size. 7680×4320 is the largest framebuffer verified on Apple Silicon.
public enum HiDPIModeCatalog {
    public static let defaultMaxFramebuffer = PointSize(width: 7680, height: 4320)

    /// Fractions of the native width, from "larger text" to "more space".
    static let scaleSteps: [Double] = [0.625, 0.75, 0.8, 0.875, 1.0, 1.125, 1.25]

    /// Point sizes to offer, smallest (largest text) first.
    public static func modes(
        forNative native: PointSize,
        maxFramebuffer: PointSize = defaultMaxFramebuffer
    ) -> [PointSize] {
        guard native.width > 0, native.height > 0 else { return [] }
        let aspect = Double(native.width) / Double(native.height)
        let sizes = scaleSteps.map { step in
            step == 1 ? native : rounded(width: Double(native.width) * step, aspect: aspect)
        }
        let fitting = sizes.filter {
            $0.doubled.width <= maxFramebuffer.width && $0.doubled.height <= maxFramebuffer.height
        }
        return Array(Set(fitting)).sorted()
    }

    /// Framebuffer the virtual display needs so that every mode gets a 2× variant.
    public static func framebuffer(for modes: [PointSize]) -> PointSize {
        PointSize(
            width: modes.map(\.width).max() ?? 0,
            height: modes.map(\.height).max() ?? 0
        ).doubled
    }

    /// 1:1 with the panel when possible — the crispest option.
    public static func preferredDefault(forNative native: PointSize, in modes: [PointSize]) -> PointSize? {
        if modes.contains(native) { return native }
        return modes.min { abs($0.width - native.width) < abs($1.width - native.width) }
    }

    /// Next mode in `direction` (+1 = more space, -1 = larger text), clamped to the ends.
    public static func step(from current: PointSize, by direction: Int, in modes: [PointSize]) -> PointSize? {
        let sorted = modes.sorted()
        guard !sorted.isEmpty else { return nil }
        let index = sorted.firstIndex(of: current)
            ?? sorted.firstIndex { $0 > current }
            ?? sorted.count - 1
        let next = min(max(index + direction, 0), sorted.count - 1)
        return sorted[next]
    }

    static func rounded(width: Double, aspect: Double) -> PointSize {
        let w = Int((width / 8).rounded()) * 8
        let h = Int((Double(w) / aspect / 2).rounded()) * 2
        return PointSize(width: w, height: h)
    }
}
