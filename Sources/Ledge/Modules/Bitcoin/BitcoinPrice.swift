import Foundation

struct BitcoinSnapshot: Codable, Equatable {
    let priceUSD: Double
    let change24hPct: Double
    /// Hourly closes for the last 24h (oldest first), used for the sparkline.
    let sparkline: [Double]
    let updatedAt: Date

    var trend: Trend {
        if change24hPct > 0.05 { return .up }
        if change24hPct < -0.05 { return .down }
        return .flat
    }

    enum Trend { case up, down, flat }
}

enum BitcoinFormat {
    static func compact(_ value: Double) -> String {
        // $63.4K, $1.23M, etc.
        let abs = value.magnitude
        if abs >= 1_000_000 {
            return String(format: "$%.2fM", value / 1_000_000)
        }
        if abs >= 1_000 {
            return String(format: "$%.1fK", value / 1_000)
        }
        return String(format: "$%.0f", value)
    }

    static func full(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: value)) ?? "$\(Int(value))"
    }

    static func change(_ pct: Double) -> String {
        let sign = pct >= 0 ? "+" : "−"
        return String(format: "\(sign)%.2f%%", abs(pct))
    }
}
