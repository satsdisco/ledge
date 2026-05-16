import Foundation

/// Contract every media source backend conforms to. Implementations are
/// source-agnostic — they read from whatever is currently publishing Now
/// Playing info to macOS, and send commands through the system media-key
/// route (which targets the now-playing app regardless of which one it is).
protocol MediaController: AnyObject {
    /// Latest known track from the system's Now Playing client, or nil.
    func currentTrack() async -> NowPlayingTrack?

    func playPause() async
    func next() async
    func previous() async

    /// Toggle the "loved" / liked state of the current track. No-op for
    /// sources that don't support it.
    func toggleLove() async
}
