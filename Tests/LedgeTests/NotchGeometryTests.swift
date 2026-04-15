import Testing
import CoreGraphics
@testable import Ledge

@Suite("NotchGeometry")
struct NotchGeometryTests {
    private static let notched = ScreenDescriptor(
        displayID: 1,
        frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
        safeAreaTop: 38,
        auxiliaryTopLeft:  CGRect(x: 0,   y: 944, width: 700, height: 38),
        auxiliaryTopRight: CGRect(x: 812, y: 944, width: 700, height: 38),
        localizedName: "Built-in"
    )

    private static let flat = ScreenDescriptor(
        displayID: 2,
        frame: CGRect(x: 1512, y: 0, width: 2560, height: 1440),
        safeAreaTop: 0,
        auxiliaryTopLeft: nil,
        auxiliaryTopRight: nil,
        localizedName: "External"
    )

    @Test func notchedScreenProducesRect() {
        let rect = NotchGeometry.notchRect(for: Self.notched, synthetic: false)
        #expect(rect != nil)
        #expect(rect?.width == 112)
        #expect(rect?.height == 38)
        #expect(rect?.minX == 700)
        #expect(rect?.maxY == 982)
    }

    @Test func flatScreenWithoutSyntheticReturnsNil() {
        #expect(NotchGeometry.notchRect(for: Self.flat, synthetic: false) == nil)
    }

    @Test func flatScreenWithSyntheticReturnsCenteredRect() {
        let rect = NotchGeometry.notchRect(for: Self.flat, synthetic: true)
        #expect(rect?.width == NotchGeometry.syntheticSize.width)
        #expect(rect?.height == NotchGeometry.syntheticSize.height)
        #expect(rect?.midX == Self.flat.frame.midX)
        #expect(rect?.maxY == Self.flat.frame.maxY)
    }

    @Test func hasHardwareNotch() {
        #expect(NotchGeometry.hasHardwareNotch(Self.notched))
        #expect(!NotchGeometry.hasHardwareNotch(Self.flat))
    }
}
