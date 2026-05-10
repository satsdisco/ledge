import SwiftUI
import AppKit

// MARK: - Collapsed

struct NotesCollapsedView: View {
    @Bindable var store: NotesStore

    var body: some View {
        HStack(spacing: 4) {
            let chars = store.todayEntry?.body.count ?? 0
            if chars == 0 {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(.white.opacity(0.35))
            } else {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                Text("\(chars)")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
    }
}

// MARK: - Expanded

private let dayHeaderFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "EEEE \u{00B7} MMM d"
    return f
}()

private let archiveDateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "MMM d"
    return f
}()

private let archiveTimeFormatter: DateFormatter = {
    let f = DateFormatter()
    f.timeStyle = .short
    return f
}()

struct NotesExpandedView: View {
    @Bindable var store: NotesStore
    @State private var draftBody: String = ""
    @FocusState private var editorFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            todaySection
            Divider().opacity(0.18)
            archiveSection
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear {
            store.ensureTodayEntry()
            draftBody = store.todayEntry?.body ?? ""
        }
        .onChange(of: draftBody) { _, newValue in
            store.updateTodayBody(newValue)
        }
    }

    // MARK: Today

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text("Today")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.95))
                Text("\u{00B7}")
                    .foregroundStyle(.white.opacity(0.3))
                Text(dayHeaderFormatter.string(from: Date()))
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.5))
                Spacer()
                if !draftBody.isEmpty {
                    Text(stats(for: draftBody))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.35))
                }
            }

            ZStack(alignment: .topLeading) {
                if draftBody.isEmpty {
                    Text("Type a quick note\u{2026}")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.3))
                        .padding(.horizontal, 4)
                        .padding(.top, 6)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $draftBody)
                    .scrollContentBackground(.hidden)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.92))
                    .focused($editorFocused)
                    .padding(.horizontal, 1)
            }
            .frame(minHeight: 110, maxHeight: 140)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(.white.opacity(editorFocused ? 0.06 : 0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(.white.opacity(editorFocused ? 0.18 : 0.08), lineWidth: 1)
            )
        }
    }

    private func stats(for body: String) -> String {
        let words = body.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
        return "\(words)w \u{00B7} \(body.count)c"
    }

    // MARK: Archive

    private var archiveSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Archive")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                if !store.archive.isEmpty {
                    Text("\(store.archive.count)")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.4))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(
                            Capsule().fill(.white.opacity(0.08))
                        )
                }
                Spacer()
            }

            if store.archive.isEmpty {
                Text("Yesterday\u{2019}s notes will appear here.")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.35))
                    .padding(.vertical, 4)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 2) {
                        ForEach(store.archive) { entry in
                            ArchiveRow(
                                entry: entry,
                                isExpanded: store.expandedArchiveIDs.contains(entry.id),
                                onToggle: { store.toggleArchiveExpansion(entry) },
                                onCopy: { store.copyToPasteboard(entry) },
                                onRemove: { store.remove(entry) }
                            )
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Archive row

private struct ArchiveRow: View {
    let entry: NoteEntry
    let isExpanded: Bool
    let onToggle: () -> Void
    let onCopy: () -> Void
    let onRemove: () -> Void
    @State private var hovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white.opacity(0.4))
                    .frame(width: 10)
                Text(archiveDateFormatter.string(from: entry.createdAt))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                Text(summary)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.4))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 4)
                if hovering {
                    iconButton("doc.on.doc", help: "Copy", action: onCopy)
                    iconButton("trash",      help: "Remove", action: onRemove)
                } else {
                    Text(archiveTimeFormatter.string(from: entry.modifiedAt))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.3))
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
            .onTapGesture { onToggle() }

            if isExpanded {
                renderedBody
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 6)
                    .padding(.top, 2)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(hovering ? .white.opacity(0.05) : .clear)
        )
        .onHover { hovering = $0 }
    }

    /// Archive entries render as markdown — headers, bullets, **bold**,
    /// _italic_, links, code spans. Falls back to plain text on parse error.
    @ViewBuilder
    private var renderedBody: some View {
        if entry.body.isEmpty {
            Text("(empty)")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.3))
        } else if let attributed = try? AttributedString(
            markdown: entry.body,
            options: AttributedString.MarkdownParsingOptions(
                interpretedSyntax: .inlineOnlyPreservingWhitespace
            )
        ) {
            Text(attributed)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.85))
                .tint(.white.opacity(0.95))
        } else {
            Text(entry.body)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.85))
        }
    }

    private var summary: String {
        let trimmed = entry.body.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "\u{2014} empty" }
        let firstLine = trimmed.split(whereSeparator: \.isNewline).first.map(String.init) ?? trimmed
        let lineCount = trimmed.split(whereSeparator: \.isNewline).count
        let prefix = String(firstLine.prefix(50))
        return "\u{00B7} \(prefix)\(lineCount > 1 ? " \u{00B7} \(lineCount) lines" : "")"
    }

    private func iconButton(_ systemName: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
                .frame(width: 18, height: 18)
                .background(
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(.white.opacity(0.10))
                )
        }
        .buttonStyle(.plain)
        .help(help)
    }
}
