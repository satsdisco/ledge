import Foundation
import AppKit
import QuickLookThumbnailing
import CryptoKit

/// AppleScript-driven media controller — the working fallback for macOS 26+,
/// where MediaRemote restricts third-party access to Now Playing metadata.
///
/// Covers Music.app and Spotify desktop. Browser-based players (YouTube
/// Music, web players) are unreachable without MediaRemote's restricted
/// info dictionary; those simply won't show up in Ledge until Apple opens
/// the API back up or we ship a helper-process workaround.
///
/// Artwork strategy:
/// - Spotify exposes `artwork url of current track` directly.
/// - Music: try the track's local file via QuickLook; for streaming tracks
///   without a local file, fall back to writing `raw data of artwork 1` to
///   our cache.
final class AppleScriptMediaController: MediaController {

    private let artworkCacheDir: URL

    /// Remembers which app most recently published a non-stopped track, so
    /// `playPause()` / `next()` / `previous()` target that app rather than
    /// guessing. Updated on every successful `currentTrack()` read.
    private var lastActiveApp: String = "Spotify"

    init() {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        self.artworkCacheDir = base.appendingPathComponent("Ledge/artwork", isDirectory: true)
        try? FileManager.default.createDirectory(at: artworkCacheDir, withIntermediateDirectories: true)
    }

    // MARK: - Read

    func currentTrack() async -> NowPlayingTrack? {
        let running = await runningApps()
        // Prefer the source that's actively playing; if both have tracks but
        // none is playing, return whichever is paused last.
        for app in ["Spotify", "Music"] where running.contains(app) {
            if let track = await query(app: app), track.state == .playing {
                lastActiveApp = app
                return track
            }
        }
        for app in ["Spotify", "Music"] where running.contains(app) {
            if let track = await query(app: app) {
                lastActiveApp = app
                return track
            }
        }
        return nil
    }

    // MARK: - Write

    func playPause() async { _ = await runScript("tell application \"\(lastActiveApp)\" to playpause") }
    func next()      async { _ = await runScript("tell application \"\(lastActiveApp)\" to next track") }
    func previous()  async { _ = await runScript("tell application \"\(lastActiveApp)\" to previous track") }

    /// Music.app exposes `favorited` on every track and we can toggle it
    /// (the renamed `loved` property from the Apple Music rebrand). Spotify
    /// removed direct AppleScript control of Liked Songs years ago, so for
    /// Spotify this is a no-op (UI hides the heart button when the source
    /// can't read/write the favorite state).
    func toggleLove() async {
        guard lastActiveApp == "Music" else { return }
        _ = await runScript("""
        tell application "Music"
            try
                set favorited of current track to (not (favorited of current track))
            end try
        end tell
        """)
    }

    // MARK: - Internals

    private func runningApps() async -> Set<String> {
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
        var set: Set<String> = []
        if raw.contains("Spotify") { set.insert("Spotify") }
        if raw.contains("Music")   { set.insert("Music") }
        return set
    }

    private func query(app: String) async -> NowPlayingTrack? {
        let script: String
        switch app {
        case "Spotify":
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
                    set pp to (player position) as string
                    set dd to "0"
                    try
                        set dd to ((duration of current track) / 1000) as string
                    end try
                    return t & "|" & a & "|" & al & "|" & s & "|" & au & "||" & pp & "|" & dd
                end if
            end tell
            return ""
            """
        case "Music":
            // Apple renamed `loved` → `favorited` in the Apple Music rebrand;
            // the old property is gone and reading it throws a -10001 type
            // mismatch. Wrap the favorited read in its own try/on-error so
            // a single missing property doesn't sink the whole query.
            script = """
            tell application "Music"
                if it is running then
                    set s to (player state as string)
                    if s is "stopped" then return "|||stopped||"
                    try
                        set t to name of current track
                        set a to artist of current track
                        set al to album of current track
                    on error
                        return ""
                    end try
                    set lvStr to ""
                    try
                        if favorited of current track then
                            set lvStr to "1"
                        else
                            set lvStr to "0"
                        end if
                    end try
                    set fp to ""
                    try
                        set fp to POSIX path of (get location of current track)
                    end try
                    set pp to (player position) as string
                    set dd to "0"
                    try
                        set dd to (duration of current track) as string
                    end try
                    return t & "|" & a & "|" & al & "|" & s & "|" & fp & "|" & lvStr & "|" & pp & "|" & dd
                end if
            end tell
            return ""
            """
        default:
            return nil
        }

        guard let raw = await runScript(script), !raw.isEmpty else { return nil }
        let parts = raw.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        guard parts.count >= 4 else { return nil }

        let stateString = parts[3]
        if stateString == "stopped" {
            return NowPlayingTrack(
                title: "", artist: "", album: nil,
                sourceName: app, state: .stopped, artworkURL: nil, isLoved: nil,
                position: nil, duration: nil
            )
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
        // Music adds a favorited flag at index 5; Spotify uses index 5 as a
        // (currently always empty) gap so its position/duration also live at
        // 6/7. Empty favorited = "couldn't read" → nil so heart stays hidden.
        let isLoved: Bool? = {
            guard app == "Music", parts.count > 5 else { return nil }
            switch parts[5] {
            case "1": return true
            case "0": return false
            default:  return nil
            }
        }()
        // AppleScript formats numbers in the user's locale — "170,819" rather
        // than "170.819" on European systems — so normalise the decimal
        // separator before parsing with Swift's locale-agnostic Double init.
        let position: Double? = parts.count > 6 ? Double(parts[6].replacingOccurrences(of: ",", with: ".")) : nil
        let duration: Double? = parts.count > 7 ? Double(parts[7].replacingOccurrences(of: ",", with: ".")) : nil

        let base = NowPlayingTrack(
            title: title, artist: artist, album: album,
            sourceName: app, state: state, artworkURL: nil, isLoved: isLoved,
            position: position, duration: duration
        )
        let url = await resolveArtworkURL(extra: artExtra, app: app, for: base)
        return NowPlayingTrack(
            title: title, artist: artist, album: album,
            sourceName: app, state: state, artworkURL: url, isLoved: isLoved,
            position: position, duration: duration
        )
    }

    private func resolveArtworkURL(extra: String, app: String, for track: NowPlayingTrack) async -> URL? {
        switch app {
        case "Spotify":
            return extra.isEmpty ? nil : URL(string: extra)
        case "Music":
            if !extra.isEmpty {
                let fileURL = URL(fileURLWithPath: extra)
                if FileManager.default.fileExists(atPath: fileURL.path),
                   let url = await cachedThumbnail(forTrackFile: fileURL, trackKey: track.artworkKey) {
                    return url
                }
            }
            return await extractMusicArtwork(trackKey: track.artworkKey)
        default:
            return nil
        }
    }

    /// Extract raw artwork bytes directly from Music.app — covers streaming
    /// tracks with no local file.
    private func extractMusicArtwork(trackKey: String) async -> URL? {
        let hash = SHA256.hash(data: Data(trackKey.utf8))
            .prefix(8).map { String(format: "%02x", $0) }.joined()
        let dest = artworkCacheDir.appendingPathComponent("music-\(hash).dat")
        if FileManager.default.fileExists(atPath: dest.path) { return dest }

        let script = """
        tell application "Music"
            try
                set art to artwork 1 of current track
                set artData to raw data of art
                set destPath to "\(dest.path)"
                set f to open for access (POSIX file destPath) with write permission
                set eof f to 0
                write artData to f
                close access f
                return destPath
            on error
                return ""
            end try
        end tell
        """
        let result = await runScript(script) ?? ""
        guard !result.isEmpty,
              FileManager.default.fileExists(atPath: result) else { return nil }
        return URL(fileURLWithPath: result)
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
