import Foundation

struct NowPlayingTrack: Equatable {
    enum PlayState: String { case playing, paused, stopped }
    enum Source: String { case music = "Music", spotify = "Spotify" }

    let title: String
    let artist: String
    let album: String?
    let source: Source
    let state: PlayState

    var isPlaying: Bool { state == .playing }
}
