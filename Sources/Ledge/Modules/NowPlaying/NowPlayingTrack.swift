import Foundation

struct NowPlayingTrack: Equatable {
    enum PlayState: String { case playing, paused, stopped }

    let title: String
    let artist: String
    let album: String?
    /// Human-readable name of the app driving playback ("Music", "Spotify",
    /// "Safari" — anything that publishes Now Playing info to macOS). Empty
    /// when we couldn't resolve a client.
    let sourceName: String
    let state: PlayState
    /// Artwork file URL (cached locally — MediaRemote returns the bytes
    /// directly, we write them to disk so AsyncImage can load them).
    let artworkURL: URL?
    /// "Loved" / liked state for the current track. `nil` when the source
    /// doesn't expose a like-state we can read (Spotify, web players).
    let isLoved: Bool?
    /// Current playback position in seconds. `nil` when unknown.
    let position: Double?
    /// Total track duration in seconds. `nil` when unknown.
    let duration: Double?

    /// Normalized 0…1 progress, or nil when either piece is missing.
    var progress: Double? {
        guard let position, let duration, duration > 0 else { return nil }
        return min(1, max(0, position / duration))
    }

    var isPlaying: Bool { state == .playing }

    /// Stable per-track key for artwork caching.
    var artworkKey: String {
        "\(sourceName)|\(artist)|\(title)"
    }
}
