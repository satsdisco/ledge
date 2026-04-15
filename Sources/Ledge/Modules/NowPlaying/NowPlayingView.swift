import SwiftUI

// MARK: - Collapsed

struct NowPlayingCollapsedView: View {
    @Bindable var state: NowPlayingState

    var body: some View {
        HStack(spacing: 4) {
            if let track = state.track, !track.title.isEmpty {
                Circle()
                    .fill(track.isPlaying ? .pink : .white.opacity(0.35))
                    .frame(width: 5, height: 5)
                Text(track.title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)
                    .frame(maxWidth: 90, alignment: .leading)
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(.white.opacity(0.3))
            }
        }
    }
}

// MARK: - Expanded

struct NowPlayingExpandedView: View {
    @Bindable var state: NowPlayingState
    let controller: MediaController

    var body: some View {
        Group {
            if let track = state.track, !track.title.isEmpty {
                playingLayout(track)
            } else {
                emptyLayout
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func playingLayout(_ track: NowPlayingTrack) -> some View {
        HStack(spacing: 12) {
            artwork(for: track)
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(.white.opacity(0.08), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.95))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(track.artist)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 2)
                transport(for: track)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
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
            Rectangle().fill(.white.opacity(0.06))
            Image(systemName: track.source == .spotify ? "music.note" : "music.note")
                .font(.system(size: 20))
                .foregroundStyle(.white.opacity(0.3))
        }
    }

    private func transport(for track: NowPlayingTrack) -> some View {
        HStack(spacing: 16) {
            transportButton("backward.fill", size: 11) {
                Task { await controller.previous(source: track.source) }
            }
            transportButton(track.isPlaying ? "pause.fill" : "play.fill", size: 14) {
                Task { await controller.playPause(source: track.source) }
            }
            transportButton("forward.fill", size: 11) {
                Task { await controller.next(source: track.source) }
            }
            Spacer()
            Text(track.source.rawValue)
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(.white.opacity(0.35))
        }
    }

    private var emptyLayout: some View {
        VStack(spacing: 6) {
            Image(systemName: "music.note")
                .font(.system(size: 20))
                .foregroundStyle(.white.opacity(0.3))
            Text("Nothing playing")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func transportButton(_ systemName: String, size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.plain)
    }
}
