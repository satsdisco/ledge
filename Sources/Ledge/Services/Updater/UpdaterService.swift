import Foundation
import Observation
import Sparkle

/// Wraps Sparkle's `SPUStandardUpdaterController` so the rest of the app
/// can drive auto-updates through a small @Observable surface.
///
/// Sparkle reads its configuration from Info.plist:
///   - `SUFeedURL`  — appcast URL (set by release)
///   - `SUPublicEDKey` — base64 EdDSA public key
///   - `SUEnableAutomaticChecks` — true for background checks
///
/// Until those keys are populated (see `docs/SPARKLE_SETUP.md`), Sparkle
/// will be quiet — `checkForUpdates()` will surface a clean error.
@Observable
final class UpdaterService: NSObject {
    private let controller: SPUStandardUpdaterController

    var canCheckForUpdates: Bool { controller.updater.canCheckForUpdates }
    var lastUpdateCheckDate: Date? { controller.updater.lastUpdateCheckDate }

    var automaticallyChecksForUpdates: Bool {
        get { controller.updater.automaticallyChecksForUpdates }
        set { controller.updater.automaticallyChecksForUpdates = newValue }
    }

    override init() {
        // `startingUpdater: true` kicks off the background scheduler immediately.
        // Delegates are nil — defaults are fine; we'd add one only for custom
        // appcast handling or pre-update prompts.
        self.controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        super.init()
        Log.app.info("Sparkle updater started; feed: \(self.feedURL ?? "<unset>", privacy: .public)")
    }

    /// User-initiated check. Shows Sparkle's standard UI for "checking…",
    /// "no update available", or "install update".
    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }

    private var feedURL: String? {
        Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String
    }
}
