import Foundation

/// A resolution in points — what System Settings calls "looks like".
public struct PointSize: Hashable, Codable, Sendable, Comparable, CustomStringConvertible {
    public var width: Int
    public var height: Int

    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }

    /// Backing store size when rendered at 2× (HiDPI).
    public var doubled: PointSize { PointSize(width: width * 2, height: height * 2) }

    public var area: Int { width * height }

    public static func < (lhs: PointSize, rhs: PointSize) -> Bool {
        lhs.area == rhs.area ? lhs.width < rhs.width : lhs.area < rhs.area
    }

    public var description: String { "\(width) × \(height)" }
}
