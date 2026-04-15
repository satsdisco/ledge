import XCTest
@testable import Ledge

final class SmokeTests: XCTestCase {
    func testRegistryBootstraps() {
        let r = ModuleRegistry()
        r.bootstrap()
        XCTAssertEqual(r.count, 0)
    }

    func testFeatureFlagDefaults() {
        XCTAssertTrue(FeatureFlags.mediaRemote)
        XCTAssertFalse(FeatureFlags.syntheticNotch)
    }
}
