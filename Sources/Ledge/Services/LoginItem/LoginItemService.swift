import Foundation
import ServiceManagement
import Observation

@Observable
final class LoginItemService {
    var isEnabled: Bool = false

    init() { refresh() }

    func refresh() {
        isEnabled = SMAppService.mainApp.status == .enabled
    }

    func set(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            refresh()
            Log.app.info("LoginItem -> \(enabled ? "enabled" : "disabled", privacy: .public)")
        } catch {
            Log.app.error("LoginItem toggle failed: \(error.localizedDescription, privacy: .public)")
            refresh()
        }
    }
}
