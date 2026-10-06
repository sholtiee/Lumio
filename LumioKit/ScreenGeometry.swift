import CoreGraphics

/// Window placement math. All rects must share one coordinate space; the
/// Accessibility API uses a top-left origin anchored to the primary screen.
public enum ScreenGeometry {
    /// Tolerance for treating a window as "filling" its screen.
    static let fillTolerance: CGFloat = 12

    /// Moves `frame` from `source` to `target`, keeping its relative position
    /// in the free space and shrinking it if it does not fit. Windows that fill
    /// the source fill the target.
    public static func map(_ frame: CGRect, from source: CGRect, to target: CGRect) -> CGRect {
        if fills(frame, source) { return target }

        let width = min(frame.width, target.width)
        let height = min(frame.height, target.height)
        let rx = relative(frame.minX - source.minX, free: source.width - frame.width)
        let ry = relative(frame.minY - source.minY, free: source.height - frame.height)

        return CGRect(
            x: (target.minX + rx * (target.width - width)).rounded(),
            y: (target.minY + ry * (target.height - height)).rounded(),
            width: width,
            height: height
        )
    }

    /// Converts between AppKit (bottom-left origin) and CG/AX (top-left origin).
    /// The conversion is its own inverse.
    public static func flip(_ rect: CGRect, primaryHeight: CGFloat) -> CGRect {
        CGRect(x: rect.minX, y: primaryHeight - rect.maxY, width: rect.width, height: rect.height)
    }

    /// Index of the rect that overlaps `frame` the most, or nil if none does.
    public static func bestMatch(for frame: CGRect, in rects: [CGRect]) -> Int? {
        let areas = rects.map { rect -> CGFloat in
            let i = rect.intersection(frame)
            return i.isNull ? 0 : i.width * i.height
        }
        guard let best = areas.indices.max(by: { areas[$0] < areas[$1] }), areas[best] > 0 else {
            return nil
        }
        return best
    }

    /// Cyclic neighbour index.
    public static func neighbour(of index: Int, count: Int, direction: Int) -> Int {
        guard count > 0 else { return 0 }
        return ((index + direction) % count + count) % count
    }

    /// Screens ordered left-to-right, then top-to-bottom — the order users expect for "next".
    public static func spatialOrder(_ rects: [CGRect]) -> [Int] {
        rects.indices.sorted { a, b in
            rects[a].minX != rects[b].minX ? rects[a].minX < rects[b].minX : rects[a].minY < rects[b].minY
        }
    }

    private static func fills(_ frame: CGRect, _ screen: CGRect) -> Bool {
        abs(frame.minX - screen.minX) <= fillTolerance &&
            abs(frame.minY - screen.minY) <= fillTolerance &&
            abs(frame.maxX - screen.maxX) <= fillTolerance &&
            abs(frame.maxY - screen.maxY) <= fillTolerance
    }

    private static func relative(_ offset: CGFloat, free: CGFloat) -> CGFloat {
        guard free > 0 else { return 0 }
        return min(max(offset / free, 0), 1)
    }
}
