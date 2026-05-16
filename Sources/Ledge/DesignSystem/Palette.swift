import SwiftUI

/// Centralized color palette. Every `.white.opacity(0.X)` and accent in Ledge
/// should resolve through this enum so the whole app reads at the same
/// hierarchy of emphasis.
///
/// Foreground tiers mirror AppKit's primary/secondary/tertiary/quaternary
/// labelColor stack: each step ~half the emphasis of the one above it. That's
/// it — four foreground stops is plenty for a dark-canvas app.
enum Palette {
    // MARK: Foreground (text + glyphs over the dark notch surface)

    /// Primary text. High emphasis — titles, active values, hero numerals.
    static let primary = Color.white.opacity(0.95)

    /// Secondary text. Supporting copy that should clearly read but not lead.
    static let secondary = Color.white.opacity(0.65)

    /// Tertiary text. Meta lines, timestamps, helper copy.
    static let tertiary = Color.white.opacity(0.40)

    /// Quaternary text. Placeholders, disabled, empty-state glyphs.
    static let quaternary = Color.white.opacity(0.22)

    // MARK: Surface chrome

    /// Hairline separator — card edges, faint dividers.
    static let separator = Color.white.opacity(0.08)

    /// Inset card / well background inside the drawer.
    static let card = Color.white.opacity(0.06)

    /// Active/pressed background for soft button states (segmented control
    /// selection, active preset, primary action chrome). One step brighter
    /// than `separator` so an active state is clearly differentiated.
    static let highlight = Color.white.opacity(0.10)

    /// The notch / collapsed pill itself. Always pure black.
    static let surface = Color.black

    // MARK: Accent

    /// The single accent color in Ledge. Currently the analog seconds-hand
    /// pink — used sparingly for attention, active state, and drop targets.
    /// Keep its budget small: if you find yourself reaching for accent on
    /// more than one element per view, you probably don't need it.
    static let accent = Color.pink
}
