import Foundation

/// Fetches BTC/USD spot + 24h change + hourly sparkline from CoinGecko.
/// Free public endpoint; rate limit is generous for our 60s polling cadence.
final class BitcoinPriceService {

    private let session: URLSession

    init() {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.timeoutIntervalForRequest = 8
        cfg.timeoutIntervalForResource = 12
        self.session = URLSession(configuration: cfg)
    }

    func fetch() async -> BitcoinSnapshot? {
        async let priceCall: (Double, Double)? = fetchPriceAndChange()
        async let sparkCall: [Double] = fetchSparkline()

        guard let (price, change) = await priceCall else { return nil }
        let spark = await sparkCall
        return BitcoinSnapshot(
            priceUSD: price,
            change24hPct: change,
            sparkline: spark,
            updatedAt: Date()
        )
    }

    // MARK: - Endpoints

    private func fetchPriceAndChange() async -> (Double, Double)? {
        let url = URL(string: "https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=usd&include_24hr_change=true")!
        do {
            let (data, _) = try await session.data(from: url)
            // Shape: {"bitcoin":{"usd":63421.0,"usd_24h_change":2.34}}
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let btc = json?["bitcoin"] as? [String: Any]
            guard let usd = btc?["usd"] as? Double else { return nil }
            let chg = (btc?["usd_24h_change"] as? Double) ?? 0
            return (usd, chg)
        } catch {
            Log.module.error("BTC price fetch failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private func fetchSparkline() async -> [Double] {
        let url = URL(string: "https://api.coingecko.com/api/v3/coins/bitcoin/market_chart?vs_currency=usd&days=1&interval=hourly")!
        do {
            let (data, _) = try await session.data(from: url)
            // Shape: {"prices":[[ms, price], [ms, price], ...]}
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let prices = json?["prices"] as? [[Any]] ?? []
            return prices.compactMap { $0.last as? Double }
        } catch {
            Log.module.error("BTC sparkline fetch failed: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }
}
