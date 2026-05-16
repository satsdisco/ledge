import SwiftUI

// MARK: - Collapsed

struct NowPlayingCollapsedView: View {
    @Bindable var state: NowPlayingState

    var body: some View {
        HStack(spacing: 4) {
            if let track = state.track, !track.title.isEmpty {
                // Accent dot signals "live, playing now" — same hue as the
                // analog seconds hand (Palette.accent is pink) so kinetic
                // elements share one accent vocabulary across modules.
                Circle()
                    .fill(track.isPlaying ? Palette.accent : Palette.tertiary)
                    .frame(width: 5, height: 5)
                Text(track.title)
                    .font(Typography.labelMedium)
                    .foregroundStyle(Palette.primary)
                    .lineLimit(1)
                    .frame(maxWidth: 90, alignment: .leading)
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(Palette.quaternary)
            }
        }
    }
}

// MARK: - Expanded

struct NowPlayingExpandedView: View {
    @Bindable var state: NowPlayingState
    @Bindable var audio: AudioOutputController
    let controller: MediaController

    /// Local timestamp of the last time `state.track` got refreshed. Used to
    /// interpolate position between polls so the progress bar advances every
    /// second instead of jumping every poll cycle.
    @State private var lastTrackRefresh = Date()
    /// Ticking "now" — driven by a SwiftUI Timer publisher when expanded.
    @State private var tickerNow = Date()

    var body: some View {
        VStack(spacing: 10) {
            Group {
                if let track = state.track, !track.title.isEmpty {
                    playingLayout(track)
                } else {
                    emptyLayout
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            if audio.volume != nil {
                VolumeBar(audio: audio)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { audio.refreshDevice() }
        .onChange(of: state.track) { _, _ in lastTrackRefresh = Date() }
        .onReceive(Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()) { now in
            tickerNow = now
        }
    }

    /// Smoothly-advancing position estimate: takes the last polled position
    /// and adds elapsed wall time since the poll, so the bar ticks every
    /// half-second between AppleScript refreshes.
    private func interpolatedPosition(for track: NowPlayingTrack) -> Double {
        guard let pos = track.position else { return 0 }
        guard track.isPlaying, let duration = track.duration else { return pos }
        let elapsed = tickerNow.timeIntervalSince(lastTrackRefresh)
        return min(duration, pos + elapsed)
    }

    /// Album art on the left (large + soft-shadowed), track metadata and
    /// transport controls on the right. Layout is vertically centered so the
    /// content sits balanced regardless of how many text lines we render.
    private func playingLayout(_ track: NowPlayingTrack) -> some View {
        HStack(alignment: .center, spacing: 16) {
            artwork(for: track)
                .frame(width: 96, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Palette.separator, lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.45), radius: 8, x: 0, y: 3)

            VStack(alignment: .leading, spacing: 3) {
                Text(track.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(track.artist)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Palette.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                if let album = track.album, !album.isEmpty {
                    Text(album)
                        .font(Typography.caption)
                        .foregroundStyle(Palette.tertiary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                Spacer(minLength: 6)
                if track.progress != nil {
                    progressBar(for: track)
                }
                transport(for: track)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// Progress bar with elapsed / remaining timestamps. Uses the
    /// interpolated position so the fill advances smoothly each tick
    /// instead of jumping every poll cycle.
    private func progressBar(for track: NowPlayingTrack) -> some View {
        let position = interpolatedPosition(for: track)
        let duration = track.duration ?? 0
        let progress = duration > 0 ? min(1, max(0, position / duration)) : 0
        return VStack(spacing: 3) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.separator)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Palette.primary, Palette.secondary],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(2, geo.size.width * progress))
                }
            }
            .frame(height: 4)
            HStack {
                Text(formatTime(position))
                Spacer()
                Text("−" + formatTime(max(0, duration - position)))
            }
            .font(.system(size: 9, weight: .medium, design: .monospaced))
            .foregroundStyle(Palette.tertiary)
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        let s = max(0, Int(seconds))
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    @ViewBuilder
    private func artwork(for track: NowPlayingTrack) -> some View {
        if let url = track.artworkURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().interpolation(.high).aspectRatio(contentMode: .fill)
                default:
                    artPlaceholder(for: track)
                }
            }
        } else {
            artPlaceholder(for: track)
        }
    }

    private func artPlaceholder(for track: NowPlayingTrack) -> some View {
        ZStack {
            LinearGradient(
                colors: [Palette.card, Palette.card.opacity(0.4)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "music.note")
                .font(.system(size: 28, weight: .regular))
                .foregroundStyle(Palette.quaternary)
        }
    }

    private func transport(for track: NowPlayingTrack) -> some View {
        HStack(spacing: 14) {
            transportButton("backward.fill", size: 12) {
                Task { await controller.previous() }
            }
            transportButton(track.isPlaying ? "pause.fill" : "play.fill", size: 16, primary: true) {
                Task { await controller.playPause() }
            }
            transportButton("forward.fill", size: 12) {
                Task { await controller.next() }
            }
            if let loved = track.isLoved {
                Button {
                    Task { await controller.toggleLove() }
                } label: {
                    Image(systemName: loved ? "heart.fill" : "heart")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(loved ? Palette.accent : Palette.secondary)
                        .frame(width: 24, height: 24)
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.plain)
                .help(loved ? "Unlove" : "Love")
            }
            Spacer()
            if !track.sourceName.isEmpty {
                Text(track.sourceName)
                    .font(Typography.glance)
                    .foregroundStyle(Palette.tertiary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(
                        Capsule().fill(Palette.separator)
                    )
            }
        }
    }

    private var emptyLayout: some View {
        VStack(spacing: 6) {
            Image(systemName: "music.note")
                .font(.system(size: 20))
                .foregroundStyle(Palette.quaternary)
            Text("Nothing playing")
                .font(Typography.body)
                .foregroundStyle(Palette.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Transport button. `primary: true` for play/pause — gets a slightly
    /// larger hit area and a pill background to anchor the control row.
    private func transportButton(_ systemName: String, size: CGFloat, primary: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size, weight: primary ? .semibold : .medium))
                .foregroundStyle(Palette.primary)
                .frame(width: primary ? 30 : 24, height: primary ? 30 : 24)
                .background(
                    Circle()
                        .fill(primary ? Palette.highlight : Color.clear)
                )
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Volume bar

/// Output-volume slider shown beneath the transport. Always visible when the
/// current output supports volume (i.e. almost always — except some HDMI
/// passthrough sinks). Useful even when no track is playing: lets the user
/// adjust an AirPlay receiver's level when keyboard volume keys are stuck on
/// the built-in output (clamshell-mode lifesaver).
private struct VolumeBar: View {
    @Bindable var audio: AudioOutputController
    @State private var localValue: Double = 0
    @State private var isEditing = false

    private var muted: Bool { audio.muted == true }

    var body: some View {
        HStack(spacing: 8) {
            Button {
                audio.toggleMute()
            } label: {
                Image(systemName: speakerIcon)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(muted ? Palette.tertiary : Palette.secondary)
                    .frame(width: 18, height: 18)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .help(muted ? "Unmute" : "Mute")

            Slider(value: $localValue, in: 0 ... 1) { editing in
                isEditing = editing
                if !editing { audio.setVolume(Float(localValue)) }
            }
            .controlSize(.mini)
            .tint(muted ? Palette.tertiary : Palette.secondary)
            .onChange(of: localValue) { _, newValue in
                if isEditing { audio.setVolume(Float(newValue)) }
            }
            .onAppear {
                if let v = audio.volume { localValue = Double(v) }
            }
            .onChange(of: audio.volume) { _, newValue in
                // External volume change (system widget, AirPods knob).
                // Don't fight the user while they're actively dragging.
                if !isEditing, let v = newValue { localValue = Double(v) }
            }

            // Currently-routed output as a passive label. Color hints
            // AirPlay (pink) vs everything else (tertiary). No interaction —
            // the slider already controls whatever this is, which is what
            // matters 99% of the time.
            Text(audio.deviceName.isEmpty ? "—" : audio.deviceName)
                .font(Typography.caption)
                .foregroundStyle(audio.isAirPlay ? Palette.accent : Palette.tertiary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: 120, alignment: .trailing)

            // One output picker — the system AirPlay route picker. Shows
            // every wireless target macOS knows about (HomePod, Apple TV,
            // Sonos, AirPods). For wired output changes the user already
            // has the macOS Sound menu bar item.
            AirPlayPickerButton()
                .frame(width: 18, height: 18)
                .help("Switch output…")
        }
        .onAppear { audio.refreshAvailableOutputs() }
    }

    private var speakerIcon: String {
        guard let v = audio.volume else { return "speaker.slash.fill" }
        if muted || v < 0.01 { return "speaker.slash.fill" }
        if v < 0.34 { return "speaker.wave.1.fill" }
        if v < 0.67 { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }
}
