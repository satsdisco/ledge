import Testing
import CoreGraphics
@testable import Ledge

@Suite("NotchGeometry")
struct NotchGeometryTests {
    private static let notched = ScreenDescriptor(
        displayID: 1,
        frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
        visibleFrame: CGRect(x: 0, y: 0, width: 1512, height: 944),
        safeAreaTop: 38,
        auxiliaryTopLeft:  CGRect(x: 0,   y: 944, width: 700, height: 38),
        auxiliaryTopRight: CGRect(x: 812, y: 944, width: 700, height: 38),
        localizedName: "Built-in"
    )

    private static let flat = ScreenDescriptor(
        displayID: 2,
        frame: CGRect(x: 1512, y: 0, width: 2560, height: 1440),
        visibleFrame: CGRect(x: 1512, y: 0, width: 2560, height: 1416),
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

    @Test func flatScreenWithSyntheticReturnsFixed185x32() {
        let rect = NotchGeometry.notchRect(for: Self.flat, synthetic: true)
        #expect(rect?.width == NotchGeometry.syntheticWidth)
        #expect(rect?.height == 32)
        // Odd syntheticWidth (185) means the rounded whole-pixel origin
        // sits 0.5pt off true center — that is deliberate (see notchRect).
        #expect(rect?.minX == (Self.flat.frame.midX - NotchGeometry.syntheticWidth / 2).rounded())
        #expect(rect?.maxY == Self.flat.frame.maxY)
    }

    @Test func hasHardwareNotch() {
        #expect(NotchGeometry.hasHardwareNotch(Self.notched))
        #expect(!NotchGeometry.hasHardwareNotch(Self.flat))
    }

    @Test func syntheticDimensionsMatchFourteenInchNotch() {
        #expect(NotchGeometry.syntheticWidth == 185)
        #expect(NotchGeometry.syntheticHeight == 32)
    }

    @Test func hardwareCollapsedInsetsThreeHorizontalOneVertical() {
        let rect = NotchGeometry.collapsedPanelRect(for: Self.notched, synthetic: false)
        // Fixture aux gap is 112×38; 3pt H / 1pt V → 106×37.
        #expect(rect?.width == 106)
        #expect(rect?.height == 37)
        #expect(rect?.minX == 703)
        #expect(rect?.maxY == 982)
    }

    @Test func syntheticCollapsedUsesRaw185x32() {
        let rect = NotchGeometry.collapsedPanelRect(for: Self.flat, synthetic: true)
        #expect(rect?.width == 185)
        #expect(rect?.height == 32)
        #expect(rect?.maxY == Self.flat.frame.maxY)
    }
}
