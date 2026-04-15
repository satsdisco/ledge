import Foundation

/// Compile-time defaults; runtime overrides applied from UserDefaults so the developer
/// pane in Settings can flip them without a rebuild.
///
/// Every gray/private-API code path MUST be gated by a flag here.
enum FeatureFlags {
    static var mediaRemote: Bool   { override("mediaRemote",   default: true)  }
    static var syntheticNotch: Bool { override("syntheticNotch", default: false) }
    static var debugOverlay: Bool  { override("debugOverlay",  default: false) }

    private static func override(_ key: String, default value: Bool) -> Bool {
        let defaults = UserDefaults.standard
        let fullKey = "ledge.flag.\(key)"
        return defaults.object(forKey: fullKey) as? Bool ?? value
    }
}
