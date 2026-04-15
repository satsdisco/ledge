import Foundation
import AppKit
import QuickLookThumbnailing
import CryptoKit

/// Public-API media controller driven by AppleScript. Polls Spotify first,
/// then Music. Never auto-launches a source app — probes `System Events`
/// for running processes first.
///
/// Artwork strategy:
/// - Spotify exposes `artwork url of current track` directly.
/// - Music has no public AppleScript artwork path. We fetch the track's
///   local file URL (if the track is local/downloaded) and generate a
///   QuickLook thumbnail on demand. Apple Music streaming tracks without
///   a local file get no artwork (acceptable; streaming users see text only).
final class AppleScriptMediaController: MediaController {

    private let artworkCacheDir: URL

    init() {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        self.artworkCacheDir = base.appendingPathComponent("Ledge/artwork", isDirectory: true)
        try? FileManager.default.createDirectory(at: artworkCacheDir, withIntermediateDirectories: true)
    }

    // MARK: - Read

    func currentTrack() async -> NowPlayingTrack? {
        let running = await runningSources()
        for source in [NowPlayingTrack.Source.spotify, .music] where running.contains(source) {
            if let track = await query(source: source), track.state != .stopped {
                return track
            }
        }
        for source in [NowPlayingTrack.Source.spotify, .music] where running.contains(source) {
            if let track = await query(source: source) {
                return track
            }
        }
        return nil
    }

    // MARK: - Write

    func playPause(source: NowPlayingTrack.Source) async {
        _ = await runScript("tell application \"\(source.rawValue)\" to playpause")
    }

    func next(source: NowPlayingTrack.Source) async {
        _ = await runScript("tell application \"\(source.rawValue)\" to next track")
    }

    func previous(source: NowPlayingTrack.Source) async {
        _ = await runScript("tell application \"\(source.rawValue)\" to previous track")
    }

    // MARK: - Internals

    private func runningSources() async -> Set<NowPlayingTrack.Source> {
        let script = """
        tell application "System Events"
            set procs to name of processes
        end tell
        set acc to ""
        if procs contains "Spotify" then set acc to acc & "Spotify,"
        if procs contains "Music" then set acc to acc & "Music,"
        return acc
        """
        let raw = await runScript(script) ?? ""
        var set: Set<NowPlayingTrack.Source> = []
        if raw.contains("Spotify") { set.insert(.spotify) }
        if raw.contains("Music")   { set.insert(.music) }
        return set
    }

    private func query(source: NowPlayingTrack.Source) async -> NowPlayingTrack? {
        let script: String
        switch source {
        case .spotify:
            // Spotify adds artwork url.
            script = """
            tell application "Spotify"
                if it is running then
                    set s to (player state as string)
                    if s is "stopped" then return "|||stopped|"
                    set t to name of current track
                    set a to artist of current track
                    set al to album of current track
                    set au to ""
                    try
                        set au to artwork url of current track
                    end try
                    return t & "|" & a & "|" & al & "|" & s & "|" & au
                end if
            end tell
            return ""
            """
        case .music:
            // Music adds POSIX path of local file when available.
            script = """
            tell application "Music"
                if it is running then
                    set s to (player state as string)
                    if s is "stopped" then return "|||stopped|"
                    try
                        set t to name of current track
                        set a to artist of current track
                        set al to album of current track
                    on error
                        return ""
                    end try
                    set fp to ""
                    try
                        set fp to POSIX path of (get location of current track)
                    end try
                    return t & "|" & a & "|" & al & "|" & s & "|" & fp
                end if
            end tell
            return ""
            """
        }

        guard let raw = await runScript(script), !raw.isEmpty else { return nil }
        let parts = raw.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        guard parts.count >= 4 else { return nil }

        let stateString = parts.count > 3 ? parts[3] : ""
        if stateString == "stopped" {
            return NowPlayingTrack(title: "", artist: "", album: nil,
                                   source: source, state: .stopped, artworkURL: nil)
        }

        let title  = parts[0]
        let artist = parts[1]
        let album  = parts[2].isEmpty ? nil : parts[2]
        let state: NowPlayingTrack.PlayState = {
            switch stateString {
            case "playing": return .playing
            case "paused":  return .paused
            default:        return .stopped
            }
        }()
        let artExtra = parts.count > 4 ? parts[4] : ""

        let base = NowPlayingTrack(
            title: title, artist: artist, album: album,
            source: source, state: state, artworkURL: nil
        )
        let url = await resolveArtworkURL(extra: artExtra, for: base)
        return NowPlayingTrack(
            title: title, artist: artist, album: album,
            source: source, state: state, artworkURL: url
        )
    }

    /// Spotify returns an https URL directly; Music returns a file path that we
    /// thumbnail via QuickLook and cache locally.
    private func resolveArtworkURL(extra: String, for track: NowPlayingTrack) async -> URL? {
        guard !extra.isEmpty else { return nil }
        switch track.source {
        case .spotify:
            return URL(string: extra)
        case .music:
            let fileURL = URL(fileURLWithPath: extra)
            guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
            return await cachedThumbnail(forTrackFile: fileURL, trackKey: track.artworkKey)
        }
    }

    private func cachedThumbnail(forTrackFile file: URL, trackKey: String) async -> URL? {
        let hash = SHA256.hash(data: Data(trackKey.utf8))
            .prefix(8).map { String(format: "%02x", $0) }.joined()
        let cached = artworkCacheDir.appendingPathComponent("\(hash).png")
        if FileManager.default.fileExists(atPath: cached.path) { return cached }

        let request = QLThumbnailGenerator.Request(
            fileAt: file,
            size: CGSize(width: 256, height: 256),
            scale: NSScreen.main?.backingScaleFactor ?? 2.0,
            representationTypes: .all
        )

        return await withCheckedContinuation { cont in
            QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { thumb, _ in
                guard let nsImage = thumb?.nsImage,
                      let tiff = nsImage.tiffRepresentation,
                      let rep = NSBitmapImageRep(data: tiff),
                      let png = rep.representation(using: .png, properties: [:]) else {
                    cont.resume(returning: nil); return
                }
                try? png.write(to: cached, options: .atomic)
                cont.resume(returning: cached)
            }
        }
    }

    private func runScript(_ source: String) async -> String? {
        await withCheckedContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                guard let script = NSAppleScript(source: source) else {
                    cont.resume(returning: nil); return
                }
                var errInfo: NSDictionary?
                let result = script.executeAndReturnError(&errInfo)
                if let err = errInfo {
                    let msg = err["NSAppleScriptErrorMessage"] as? String ?? "unknown"
                    let num = err["NSAppleScriptErrorNumber"] as? Int ?? 0
                    Log.media.error("AppleScript error \(num): \(msg, privacy: .public)")
                    cont.resume(returning: nil); return
                }
                let string = result.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines)
                cont.resume(returning: string)
            }
        }
    }
}
