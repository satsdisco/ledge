import SwiftUI
import AppKit

/// Centralized motion tokens. Every animation in Ledge should reach for one
/// of these — never a raw `.easeInOut` or one-off spring. Three is enough.
enum Motion {
    /// Hover-expand / drop-bloom. The "wow" transition.
    static let express: Animation = .interpolatingSpring(stiffness: 320, damping: 28)

    /// Content swap inside the panel (module switch, state changes).
    static let calm: Animation = .interpolatingSpring(stiffness: 220, damping: 30)

    /// Dismiss + micro-feedback.
    static let snap: Animation = .interpolatingSpring(stiffness: 480, damping: 32)

    /// Reduce-Motion fallback. Crossfade only.
    static let reduced: Animation = .easeOut(duration: 0.12)

    /// Pick the right animation honoring the system Reduce Motion preference.
    @MainActor
    static func auto(_ token: Animation) -> Animation {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? reduced : token
    }
}
