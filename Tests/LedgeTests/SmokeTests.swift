import Testing
@testable import Ledge

@Suite("Smoke")
struct SmokeTests {
    @Test func registryBootstraps() {
        let r = ModuleRegistry()
        r.bootstrap()
        #expect(r.count == 0)
    }

    @Test func featureFlagDefaults() {
        #expect(FeatureFlags.mediaRemote == true)
        #expect(FeatureFlags.syntheticNotch == false)
    }
}
