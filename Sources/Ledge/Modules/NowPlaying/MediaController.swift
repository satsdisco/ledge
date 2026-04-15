import Foundation

/// Contract every media source backend conforms to. v1 has one implementation
/// (`AppleScriptMediaController`). See ADR-0006 for why MediaRemote is absent.
protocol MediaController: AnyObject {
    /// Latest known track from any running source, or nil.
    func currentTrack() async -> NowPlayingTrack?

    func playPause(source: NowPlayingTrack.Source) async
    func next(source: NowPlayingTrack.Source) async
    func previous(source: NowPlayingTrack.Source) async
}
