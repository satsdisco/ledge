import Foundation
import CoreLocation
import Observation

/// Weather snapshot for a single clock entry. Stored in `WeatherStore` keyed
/// by timezone identifier.
struct WeatherSnapshot: Codable, Equatable {
    let temperatureCelsius: Double
    let weatherCode: Int   // Open-Meteo / WMO code
    let fetchedAt: Date

    /// SF Symbol matching the WMO weather code.
    var iconName: String {
        switch weatherCode {
        case 0:               return "sun.max.fill"
        case 1, 2:            return "cloud.sun.fill"
        case 3:               return "cloud.fill"
        case 45, 48:          return "cloud.fog.fill"
        case 51, 53, 55:      return "cloud.drizzle.fill"
        case 56, 57:          return "cloud.sleet.fill"
        case 61, 63, 65:      return "cloud.rain.fill"
        case 66, 67:          return "cloud.sleet.fill"
        case 71, 73, 75, 77:  return "cloud.snow.fill"
        case 80, 81, 82:      return "cloud.heavyrain.fill"
        case 85, 86:          return "cloud.snow.fill"
        case 95, 96, 99:      return "cloud.bolt.rain.fill"
        default:              return "questionmark.circle"
        }
    }
}

/// Holds the current weather snapshot per timezone identifier, observable so
/// SwiftUI tiles update when fetches complete. The store is the single source
/// of truth — the service writes to it; the view reads from it.
@Observable
final class WeatherStore {
    /// Keyed by `ClockEntry.timeZoneIdentifier`.
    var snapshots: [String: WeatherSnapshot] = [:]
    /// True when at least one fetch is in flight (used by the UI to dim
    /// stale data, optional).
    var isFetching: Bool = false
}

/// Fetches and caches current weather for a list of timezone-identified
/// clock entries. Uses Open-Meteo's public API (no key, no rate limit at
/// our volume) and Apple's CoreLocation geocoder to resolve TZ → city →
/// coordinates. Results cache to disk for 30 minutes.
@MainActor
final class WeatherService {
    private let store: WeatherStore
    private let cacheURL: URL
    private let geocoder = CLGeocoder()
    /// Lat/lon results cache — geocoding is rate-limited so we keep these
    /// for the process lifetime once resolved.
    private var coordinatesByTZ: [String: CLLocationCoordinate2D] = [:]
    private let session = URLSession.shared
    private let ttl: TimeInterval = 30 * 60   // 30 minutes
    private var refreshTimer: Timer?

    init(store: WeatherStore) {
        self.store = store
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        self.cacheURL = base.appendingPathComponent("Ledge/weather.json")
        try? FileManager.default.createDirectory(at: cacheURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        loadCache()
    }

    /// Trigger a refresh for every supplied entry. Skips entries whose
    /// cached snapshot is still fresh (within TTL).
    func refresh(for tzIdentifiers: [String]) {
        for tz in tzIdentifiers {
            if let cached = store.snapshots[tz],
               Date().timeIntervalSince(cached.fetchedAt) < ttl {
                continue
            }
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.store.isFetching = true
                if let snap = await self.fetchOne(timeZoneIdentifier: tz) {
                    self.store.snapshots[tz] = snap
                    self.persistCache()
                }
                self.store.isFetching = false
            }
        }
    }

    func startPolling(_ tzProvider: @escaping () -> [String]) {
        refresh(for: tzProvider())
        let t = Timer.scheduledTimer(withTimeInterval: ttl, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh(for: tzProvider()) }
        }
        RunLoop.main.add(t, forMode: .common)
        refreshTimer = t
    }

    // MARK: - Internals

    private func fetchOne(timeZoneIdentifier tz: String) async -> WeatherSnapshot? {
        let coord: CLLocationCoordinate2D
        if let cached = coordinatesByTZ[tz] {
            coord = cached
        } else {
            // Geocode using the city portion of the TZ identifier, e.g.
            // "America/New_York" → "New York". Apple's geocoder handles
            // unknown strings by returning empty — caller can ignore.
            let city = cityFromTimeZone(tz)
            do {
                let placemarks = try await geocoder.geocodeAddressString(city)
                guard let loc = placemarks.first?.location?.coordinate else { return nil }
                coordinatesByTZ[tz] = loc
                coord = loc
            } catch {
                Log.module.error("Weather geocode failed for \(tz, privacy: .public): \(String(describing: error), privacy: .public)")
                return nil
            }
        }

        let url = URL(string:
            "https://api.open-meteo.com/v1/forecast?latitude=\(coord.latitude)&longitude=\(coord.longitude)&current=temperature_2m,weathercode"
        )!
        do {
            let (data, _) = try await session.data(from: url)
            let resp = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
            return WeatherSnapshot(
                temperatureCelsius: resp.current.temperature_2m,
                weatherCode: resp.current.weathercode,
                fetchedAt: Date()
            )
        } catch {
            Log.module.error("Weather fetch failed for \(tz, privacy: .public): \(String(describing: error), privacy: .public)")
            return nil
        }
    }

    private func cityFromTimeZone(_ tz: String) -> String {
        // "Europe/London" → "London"; "America/New_York" → "New York".
        let last = tz.split(separator: "/").last.map(String.init) ?? tz
        return last.replacingOccurrences(of: "_", with: " ")
    }

    // MARK: - Cache I/O

    private struct OpenMeteoResponse: Decodable {
        struct Current: Decodable {
            let temperature_2m: Double
            let weathercode: Int
        }
        let current: Current
    }

    private func loadCache() {
        guard let data = try? Data(contentsOf: cacheURL),
              let decoded = try? JSONDecoder().decode([String: WeatherSnapshot].self, from: data)
        else { return }
        store.snapshots = decoded
    }

    private func persistCache() {
        guard let data = try? JSONEncoder().encode(store.snapshots) else { return }
        try? data.write(to: cacheURL, options: .atomic)
    }
}
