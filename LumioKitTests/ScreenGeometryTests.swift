import CoreGraphics
import Testing
@testable import LumioKit

struct ScreenGeometryTests {
    // Built-in 1512×945 (minus 33pt menu bar) at the origin, 2560×1440 external to its right.
    let laptop = CGRect(x: 0, y: 33, width: 1512, height: 912)
    let external = CGRect(x: 1512, y: 25, width: 2560, height: 1415)

    @Test func keepsRelativePosition() {
        let window = CGRect(x: 256, y: 33, width: 1000, height: 600) // halfway across free width, top
        let mapped = ScreenGeometry.map(window, from: laptop, to: external)
        #expect(mapped.size == window.size)
        // x: 1512 + 0.5 × (2560 − 1000); y: top of the external's visible area
        #expect(mapped.origin == CGPoint(x: 2292, y: 25))
    }

    @Test func shrinksWindowsThatDoNotFit() {
        let window = CGRect(x: 1600, y: 100, width: 2400, height: 1300)
        let mapped = ScreenGeometry.map(window, from: external, to: laptop)
        #expect(mapped.width == laptop.width)
        #expect(mapped.height == laptop.height)
        #expect(laptop.contains(mapped))
    }

    @Test func filledWindowFillsTarget() {
        let window = laptop.insetBy(dx: 4, dy: 4)
        #expect(ScreenGeometry.map(window, from: laptop, to: external) == external)
    }

    @Test func flipIsItsOwnInverse() {
        let appKit = CGRect(x: 1512, y: -495, width: 2560, height: 1440)
        let flipped = ScreenGeometry.flip(appKit, primaryHeight: 945)
        #expect(flipped == CGRect(x: 1512, y: 0, width: 2560, height: 1440))
        #expect(ScreenGeometry.flip(flipped, primaryHeight: 945) == appKit)
    }

    @Test func bestMatchPicksLargestOverlap() {
        let window = CGRect(x: 1400, y: 100, width: 400, height: 300) // mostly on the external
        #expect(ScreenGeometry.bestMatch(for: window, in: [laptop, external]) == 1)
        #expect(ScreenGeometry.bestMatch(for: CGRect(x: -900, y: 0, width: 10, height: 10), in: [laptop]) == nil)
    }

    @Test func neighbourWraps() {
        #expect(ScreenGeometry.neighbour(of: 1, count: 2, direction: 1) == 0)
        #expect(ScreenGeometry.neighbour(of: 0, count: 3, direction: -1) == 2)
    }

    @Test func spatialOrderIsLeftToRight() {
        let left = CGRect(x: -1920, y: 0, width: 1920, height: 1080)
        #expect(ScreenGeometry.spatialOrder([external, laptop, left]) == [2, 1, 0])
    }
}
