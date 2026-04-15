import Foundation

struct NowPlayingTrack: Equatable {
    enum PlayState: String { case playing, paused, stopped }
    enum Source: String { case music = "Music", spotify = "Spotify" }

    let title: String
    let artist: String
    let album: String?
    let source: Source
    let state: PlayState
    /// Artwork, if available. May be an https URL (Spotify CDN) or a file URL
    /// (local cache populated from a QuickLook thumbnail of the Music track file).
    let artworkURL: URL?

    var isPlaying: Bool { state == .playing }

    /// Stable per-track key for artwork caching.
    var artworkKey: String {
        "\(source.rawValue)|\(artist)|\(title)"
    }
}
