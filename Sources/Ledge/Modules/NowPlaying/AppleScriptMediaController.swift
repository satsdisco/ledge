import Foundation

/// Public-API media controller driven by AppleScript. Polls Spotify first,
/// then Music. Never auto-launches a source app — probes `System Events`
/// for running processes first.
final class AppleScriptMediaController: MediaController {

    // MARK: - Read

    func currentTrack() async -> NowPlayingTrack? {
        let running = await runningSources()
        for source in [NowPlayingTrack.Source.spotify, .music] where running.contains(source) {
            if let track = await query(source: source), track.state != .stopped {
                return track
            }
        }
        // If nothing is playing but something is running, return the most recent paused state.
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
        // Spotify uses "previous track"; Music accepts "previous track" too.
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
            script = """
            tell application "Spotify"
                if it is running then
                    set s to (player state as string)
                    if s is "stopped" then return "|||stopped"
                    set t to name of current track
                    set a to artist of current track
                    set al to album of current track
                    return t & "|" & a & "|" & al & "|" & s
                end if
            end tell
            return ""
            """
        case .music:
            script = """
            tell application "Music"
                if it is running then
                    set s to (player state as string)
                    if s is "stopped" then return "|||stopped"
                    try
                        set t to name of current track
                        set a to artist of current track
                        set al to album of current track
                    on error
                        return ""
                    end try
                    return t & "|" & a & "|" & al & "|" & s
                end if
            end tell
            return ""
            """
        }

        guard let raw = await runScript(script), !raw.isEmpty else { return nil }
        let parts = raw.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 4 else {
            return parts.last == "stopped"
                ? NowPlayingTrack(title: "", artist: "", album: nil, source: source, state: .stopped)
                : nil
        }
        let state: NowPlayingTrack.PlayState = {
            switch parts[3] {
            case "playing": return .playing
            case "paused":  return .paused
            default:        return .stopped
            }
        }()
        return NowPlayingTrack(
            title: parts[0],
            artist: parts[1],
            album: parts[2].isEmpty ? nil : parts[2],
            source: source,
            state: state
        )
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
