import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - Collapsed

struct FileShelfCollapsedView: View {
    @Bindable var store: FileShelfStore

    var body: some View {
        HStack(spacing: 4) {
            if store.items.isEmpty {
                Image(systemName: "tray")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(Palette.tertiary)
            } else {
                Image(systemName: "tray.full.fill")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Palette.primary)
                Text("\(store.items.count)")
                    .font(Typography.labelMedium)
                    .monospacedDigit()
                    .foregroundStyle(Palette.primary)
            }
        }
    }
}

// MARK: - Expanded

struct FileShelfExpandedView: View {
    @Bindable var store: FileShelfStore

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if store.items.isEmpty {
                emptyState
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(store.items) { item in
                            ShelfItemView(item: item, store: store)
                        }
                    }
                    .padding(.horizontal, 14)
                }
            }

            if store.items.contains(where: { !$0.isPinned }) {
                Button {
                    store.clearUnpinned()
                } label: {
                    Text("Clear")
                        .font(Typography.labelMedium)
                        .foregroundStyle(Palette.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(Palette.separator)
                        )
                }
                .buttonStyle(.plain)
                .padding(.trailing, 14)
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "tray")
                .font(.system(size: 20))
                .foregroundStyle(Palette.quaternary)
            Text("Drop files here")
                .font(Typography.body)
                .foregroundStyle(Palette.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Item cell

private struct ShelfItemView: View {
    let item: ShelfItem
    @Bindable var store: FileShelfStore
    @State private var hovering = false

    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .topTrailing) {
                thumbnail
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Palette.separator, lineWidth: 1)
                    )
                    .opacity(item.isStale ? 0.4 : 1.0)

                if item.isPinned {
                    // Pin badge — blue rather than Palette.accent so the "saved/
                    // pinned" affordance reads distinctly from kinetic accents.
                    Image(systemName: "pin.fill")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(3)
                        .background(Circle().fill(.blue))
                        .offset(x: 4, y: -4)
                }
            }
            Text(item.displayName)
                .font(Typography.caption)
                .foregroundStyle(Palette.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .truncationMode(.middle)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: 72)
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(hovering ? Palette.separator : .clear)
        )
        .onHover { hovering = $0 }
        .contextMenu { contextMenuItems }
        .onDrag {
            if let url = item.resolvedURL {
                return NSItemProvider(object: url as NSURL)
            }
            return NSItemProvider()
        }
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let url = item.resolvedURL {
            let icon = NSWorkspace.shared.icon(forFile: url.path)
            Image(nsImage: icon)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .padding(2)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(Palette.card)
                Image(systemName: "questionmark")
                    .font(.system(size: 16))
                    .foregroundStyle(Palette.tertiary)
            }
        }
    }

    @ViewBuilder
    private var contextMenuItems: some View {
        if let _ = item.resolvedURL {
            Button(item.isPinned ? "Unpin" : "Pin") { store.togglePin(item) }
            Button("Reveal in Finder")    { store.revealInFinder(item) }
            Button("Copy Path")            { store.copyPath(item) }
            Divider()
        }
        Button("Remove", role: .destructive) { store.remove(item) }
    }
}
