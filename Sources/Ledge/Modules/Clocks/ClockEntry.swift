import Foundation

struct ClockEntry: Codable, Identifiable, Hashable {
    enum Style: String, Codable, CaseIterable { case digital, analog }

    let id: UUID
    var timeZoneIdentifier: String
    /// Short label shown above the time (e.g. "NYC", "TYO"). Nil = compute from zone.
    var label: String?
    var style: Style = .digital

    var timeZone: TimeZone? { TimeZone(identifier: timeZoneIdentifier) }

    var displayLabel: String {
        if let label, !label.isEmpty { return label }
        return Self.derivedLabel(for: timeZoneIdentifier)
    }

    /// Offset from user's local time, e.g. "+5h" or "−3h".
    func offsetLabel(from reference: TimeZone = .current) -> String {
        guard let tz = timeZone else { return "" }
        let diff = tz.secondsFromGMT() - reference.secondsFromGMT()
        let hours = diff / 3600
        if hours == 0 { return "now" }
        let sign = hours > 0 ? "+" : "−"
        return "\(sign)\(abs(hours))h"
    }

    static func derivedLabel(for identifier: String) -> String {
        let tail = identifier.split(separator: "/").last.map(String.init) ?? identifier
        return tail.replacingOccurrences(of: "_", with: " ").uppercased()
    }

    // Custom decoding so old saved data without `style` still loads.
    enum CodingKeys: String, CodingKey {
        case id, timeZoneIdentifier, label, style
    }

    init(id: UUID = UUID(), timeZoneIdentifier: String, label: String? = nil, style: Style = .digital) {
        self.id = id
        self.timeZoneIdentifier = timeZoneIdentifier
        self.label = label
        self.style = style
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(UUID.self, forKey: .id)
        self.timeZoneIdentifier = try c.decode(String.self, forKey: .timeZoneIdentifier)
        self.label = try c.decodeIfPresent(String.self, forKey: .label)
        self.style = (try? c.decode(Style.self, forKey: .style)) ?? .digital
    }
}
