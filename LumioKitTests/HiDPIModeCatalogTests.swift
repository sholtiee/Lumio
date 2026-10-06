import Testing
@testable import LumioKit

struct HiDPIModeCatalogTests {
    @Test func qhdPanelOffersNativeAndCommonScales() {
        let modes = HiDPIModeCatalog.modes(forNative: PointSize(width: 2560, height: 1440))
        #expect(modes == [
            PointSize(width: 1600, height: 900),
            PointSize(width: 1920, height: 1080),
            PointSize(width: 2048, height: 1152),
            PointSize(width: 2240, height: 1260),
            PointSize(width: 2560, height: 1440),
            PointSize(width: 2880, height: 1620),
            PointSize(width: 3200, height: 1800),
        ])
    }

    @Test func framebufferLimitDropsModesThatDoNotFit() {
        let modes = HiDPIModeCatalog.modes(
            forNative: PointSize(width: 2560, height: 1440),
            maxFramebuffer: PointSize(width: 5120, height: 2880)
        )
        #expect(modes.last == PointSize(width: 2560, height: 1440))
    }

    @Test func ultrawideKeepsAspectAndEvenHeights() {
        let modes = HiDPIModeCatalog.modes(forNative: PointSize(width: 3440, height: 1440))
        #expect(modes.contains(PointSize(width: 3440, height: 1440)))
        #expect(modes.allSatisfy { $0.height % 2 == 0 && $0.width % 8 == 0 })
        #expect(modes.allSatisfy { $0.doubled.width <= 7680 })
    }

    @Test func fullHDPanel() {
        let modes = HiDPIModeCatalog.modes(forNative: PointSize(width: 1920, height: 1080))
        #expect(modes.first == PointSize(width: 1200, height: 676))
        #expect(modes.contains(PointSize(width: 1920, height: 1080)))
        #expect(modes.last == PointSize(width: 2400, height: 1350))
    }

    @Test func framebufferIsTwiceTheLargestMode() {
        let fb = HiDPIModeCatalog.framebuffer(for: [PointSize(width: 2560, height: 1440), PointSize(width: 3200, height: 1800)])
        #expect(fb == PointSize(width: 6400, height: 3600))
    }

    @Test func defaultIsOneToOne() {
        let native = PointSize(width: 2560, height: 1440)
        let modes = HiDPIModeCatalog.modes(forNative: native)
        #expect(HiDPIModeCatalog.preferredDefault(forNative: native, in: modes) == native)
    }

    @Test func stepMovesAndClamps() {
        let modes = HiDPIModeCatalog.modes(forNative: PointSize(width: 2560, height: 1440))
        let native = PointSize(width: 2560, height: 1440)
        #expect(HiDPIModeCatalog.step(from: native, by: 1, in: modes) == PointSize(width: 2880, height: 1620))
        #expect(HiDPIModeCatalog.step(from: native, by: -1, in: modes) == PointSize(width: 2240, height: 1260))
        #expect(HiDPIModeCatalog.step(from: PointSize(width: 3200, height: 1800), by: 1, in: modes) == PointSize(width: 3200, height: 1800))
        #expect(HiDPIModeCatalog.step(from: PointSize(width: 1600, height: 900), by: -1, in: modes) == PointSize(width: 1600, height: 900))
    }
}
