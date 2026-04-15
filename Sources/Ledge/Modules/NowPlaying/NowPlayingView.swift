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
        VStack(spacing: 10) {
            if let track = state.track, !track.title.isEmpty {
                VStack(spacing: 2) {
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
                    Text(track.source.rawValue)
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(.white.opacity(0.35))
                }
                .padding(.horizontal, 12)

                HStack(spacing: 22) {
                    transportButton("backward.fill") {
                        Task { await controller.previous(source: track.source) }
                    }
                    transportButton(track.isPlaying ? "pause.fill" : "play.fill") {
                        Task { await controller.playPause(source: track.source) }
                    }
                    .font(.system(size: 16, weight: .medium))
                    transportButton("forward.fill") {
                        Task { await controller.next(source: track.source) }
                    }
                }
            } else {
                VStack(spacing: 4) {
                    Image(systemName: "music.note")
                        .font(.system(size: 18))
                        .foregroundStyle(.white.opacity(0.3))
                    Text("Nothing playing")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .padding(.vertical, 10)
            }
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
    }

    private func transportButton(_ systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
    }
}
