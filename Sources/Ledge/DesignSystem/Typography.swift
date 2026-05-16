import SwiftUI

/// Centralized typography scale. Every text size in Ledge should reach for one
/// of these — never a raw `.font(.system(size: 12, ...))`.
///
/// Ledge is a small-surface app: most text lives at 8-11pt. The scale is
/// opinionated about which sizes earn their keep, and weights/designs are
/// baked in so call sites stay terse.
///
/// The scale runs from "glance" (smallest, for the always-on collapsed strip)
/// up to "hero" (timer / BTC price). Sizes between these slots are deliberate
/// — pick the closest token, don't add a new one.
enum Typography {
    /// 8pt semibold — collapsed-strip annotations (TZ codes, micro labels).
    /// Below the practical lower bound for body text; use only when space is
    /// truly scarce.
    static let glance = Font.system(size: 8, weight: .semibold)

    /// 9pt monospaced regular — secondary data lines (offsets, dates, meta).
    /// Mono so digits don't dance.
    static let meta = Font.system(size: 9, weight: .regular, design: .monospaced)

    /// 9pt regular — proportional captions (filenames, footnotes, helper copy).
    static let caption = Font.system(size: 9, weight: .regular)

    /// 10pt medium — button labels, counters, secondary glance values.
    /// Lighter weight than `label` for elements that shouldn't lead.
    static let labelMedium = Font.system(size: 10, weight: .medium)

    /// 10pt semibold — primary labels (city names, module titles in the strip).
    static let label = Font.system(size: 10, weight: .semibold)

    /// 11pt regular — body text, descriptions, settings field copy.
    static let body = Font.system(size: 11, weight: .regular)

    /// 13pt semibold — section headers in the expanded panel.
    static let title = Font.system(size: 13, weight: .semibold)

    /// 20pt monospaced semibold — digital time, prices, primary numerals.
    static let display = Font.system(size: 20, weight: .semibold, design: .monospaced)

    /// 28pt monospaced semibold — hero numerals (timer countdown).
    static let hero = Font.system(size: 28, weight: .semibold, design: .monospaced)
}
