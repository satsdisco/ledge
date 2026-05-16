import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - Collapsed

struct ClipboardCollapsedView: View {
    @Bindable var store: ClipboardStore

    var body: some View {
        HStack(spacing: 4) {
            if store.items.isEmpty {
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(Palette.tertiary)
            } else {
                Image(systemName: "doc.on.clipboard.fill")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Palette.primary)
                Text("\(store.items.count)")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Palette.primary)
            }
        }
    }
}

// MARK: - Expanded

private enum CaptureFlash {
    case none, captured, skipped
}

@MainActor
private enum ClipboardFocus: Hashable {
    case search
    case list
}

struct ClipboardExpandedView: View {
    @Bindable var store: ClipboardStore
    @State private var captureFlash: CaptureFlash = .none
    @State private var editingID: UUID?
    @FocusState private var focus: ClipboardFocus?

    var body: some View {
        VStack(spacing: 6) {
            header
            if store.items.isEmpty {
                emptyState
            } else {
                listView
                keyHintsFooter
            }
        }
        .padding(.top, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            store.ensureSelectionValid()
            focus = .list
        }
        .onChange(of: store.searchQuery) { _, _ in
            store.ensureSelectionValid()
        }
        .onChange(of: store.items.count) { _, _ in
            store.ensureSelectionValid()
        }
        // Global key handling — applied to the whole view so it works
        // whether the focus is in the list or the search field.
        .onKeyPress(.upArrow)   { handleArrow(-1) }
        .onKeyPress(.downArrow) { handleArrow(+1) }
        .onKeyPress(.return)    { handleReturn() }
        .onKeyPress(.delete)    { handleDelete() }
        .onKeyPress(.escape)    { handleEscape() }
        .onKeyPress(.space)     { handleSpace() }
        .onKeyPress(characters: .alphanumerics, phases: .down) { press in
            handleCharacter(press)
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 10))
                .foregroundStyle(Palette.tertiary)
            TextField("Search", text: $store.searchQuery)
                .textFieldStyle(.plain)
                .font(.system(size: 11))
                .foregroundStyle(Palette.primary)
                .focused($focus, equals: .search)

            Button(action: capture) {
                Text(captureButtonLabel)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(captureFlash == .none ? Palette.secondary : Palette.primary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(captureBgFill)
                    )
            }
            .buttonStyle(.plain)
            .help("Stash whatever's on the clipboard (\u{2303}\u{2325}V)")

            if store.items.contains(where: { !$0.isPinned }) {
                Button(action: { store.clearUnpinned() }) {
                    Text("Clear")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Palette.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(Palette.separator)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
    }

    private var captureButtonLabel: String {
        switch captureFlash {
        case .captured: return "Captured"
        case .skipped:  return "Skipped"
        case .none:     return "Capture"
        }
    }

    private var captureBgFill: Color {
        switch captureFlash {
        // Flashes get a stronger highlight for the brief moment we want the
        // user to notice the capture succeeded (or got skipped). 0.18 white
        // doesn't live in the palette — stays inline since it's purely
        // transient micro-feedback.
        case .captured: return .white.opacity(0.18)
        case .skipped:  return .white.opacity(0.18)
        case .none:     return Palette.highlight
        }
    }

    private func capture() {
        let result = store.captureFromPasteboard()
        switch result {
        case .captured:        flashCapture(.captured)
        case .skippedConcealed: flashCapture(.skipped)
        case .empty: break
        }
    }

    private func flashCapture(_ kind: CaptureFlash) {
        withAnimation(.easeOut(duration: 0.12)) { captureFlash = kind }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            withAnimation(.easeOut(duration: 0.2)) { captureFlash = .none }
        }
    }

    // MARK: List

    private var listView: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 4) {
                    ForEach(Array(store.visibleItems.enumerated()), id: \.element.id) { offset, item in
                        ClipboardRowView(
                            item: item,
                            store: store,
                            isSelected: store.selectedID == item.id,
                            shortcutNumber: offset < 9 ? offset + 1 : nil,
                            isEditing: editingID == item.id,
                            onBeginEdit: { editingID = item.id },
                            onEndEdit: { editingID = nil }
                        )
                        .id(item.id)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
            .focused($focus, equals: .list)
            .onChange(of: store.selectedID) { _, new in
                guard let new else { return }
                withAnimation(.easeOut(duration: 0.15)) {
                    proxy.scrollTo(new, anchor: .center)
                }
            }
        }
    }

    private var keyHintsFooter: some View {
        HStack(spacing: 10) {
            keyHint("\u{2191}\u{2193}", "navigate")
            keyHint("\u{23CE}", "paste")
            keyHint("space", "preview")
            keyHint("\u{2318}F", "search")
            Spacer()
            Text("click to enable keys")
                .font(.system(size: 8, weight: .regular))
                .foregroundStyle(Palette.quaternary)
                .italic()
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 6)
    }

    private func keyHint(_ key: String, _ label: String) -> some View {
        HStack(spacing: 3) {
            Text(key)
                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                .foregroundStyle(Palette.secondary)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Palette.highlight)
                )
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(Palette.tertiary)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 20))
                .foregroundStyle(Palette.quaternary)
            Text("Drop or press \u{2303}\u{2325}V to stash")
                .font(.system(size: 11))
                .foregroundStyle(Palette.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Key handling

    private func handleArrow(_ delta: Int) -> KeyPress.Result {
        guard editingID == nil else { return .ignored }
        store.moveSelection(by: delta)
        focus = .list
        return .handled
    }

    private func handleReturn() -> KeyPress.Result {
        if editingID != nil { return .ignored } // Editor handles its own return.
        guard let id = store.selectedID,
              let item = store.visibleItems.first(where: { $0.id == id }) else { return .ignored }
        store.copyToPasteboard(item)
        return .handled
    }

    private func handleDelete() -> KeyPress.Result {
        guard editingID == nil else { return .ignored }
        guard focus != .search else { return .ignored } // let search field clear chars
        guard let id = store.selectedID,
              let item = store.visibleItems.first(where: { $0.id == id }) else { return .ignored }
        store.remove(item)
        return .handled
    }

    private func handleEscape() -> KeyPress.Result {
        if editingID != nil { editingID = nil; return .handled }
        if !store.searchQuery.isEmpty { store.searchQuery = ""; return .handled }
        if focus == .search { focus = .list; return .handled }
        return .ignored
    }

    private func handleSpace() -> KeyPress.Result {
        guard editingID == nil, focus != .search else { return .ignored }
        guard let id = store.selectedID,
              let item = store.visibleItems.first(where: { $0.id == id }) else { return .ignored }
        ClipboardQuickLook.shared.preview(item, store: store)
        return .handled
    }

    private func handleCharacter(_ press: KeyPress) -> KeyPress.Result {
        // ⌘1–9 — copy Nth visible entry.
        if press.modifiers == .command,
           let digit = press.characters.first?.wholeNumberValue,
           (1...9).contains(digit) {
            if let item = store.selectNth(digit) {
                store.copyToPasteboard(item)
                return .handled
            }
        }
        // ⌘F — focus search.
        if press.modifiers == .command, press.characters == "f" {
            focus = .search
            return .handled
        }
        return .ignored
    }
}

// MARK: - Row

private struct ClipboardRowView: View {
    let item: ClipboardItem
    @Bindable var store: ClipboardStore
    let isSelected: Bool
    let shortcutNumber: Int?
    let isEditing: Bool
    let onBeginEdit: () -> Void
    let onEndEdit: () -> Void

    @State private var hovering = false

    var body: some View {
        Group {
            if isEditing {
                editor
            } else {
                row
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(rowBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(isSelected ? Palette.highlight : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture {
            store.selectedID = item.id
            store.copyToPasteboard(item)
        }
        .contextMenu { contextMenu }
        .onDrag { dragProvider() }
    }

    private var rowBackground: Color {
        if isSelected { return Palette.highlight }
        return hovering ? Palette.separator : Palette.card
    }

    // MARK: Row content (non-edit)

    private var row: some View {
        HStack(alignment: .top, spacing: 8) {
            iconBadge
                .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 1) {
                titleLine
                Text(secondaryLine)
                    .font(.system(size: 9))
                    .foregroundStyle(Palette.tertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            if hovering || isSelected {
                actionButtons
            } else {
                metadataIcons
            }
        }
    }

    private var metadataIcons: some View {
        HStack(spacing: 4) {
            if item.hasRichText {
                Text("RTF")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(Palette.secondary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(Palette.separator)
                    )
            }
            if item.kind == .image, item.ocrText != nil {
                Text("Aa")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(Palette.secondary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(Palette.highlight)
                    )
                    .help("This image has recognized text. Right-click to use it.")
            }
            if item.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(Palette.secondary)
            }
            if let n = shortcutNumber {
                Text("\u{2318}\(n)")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(Palette.tertiary)
            }
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 2) {
            iconButton(item.isPinned ? "pin.slash.fill" : "pin",
                       help: item.isPinned ? "Unpin" : "Pin") {
                store.togglePin(item)
            }
            if item.kind == .text {
                iconButton("pencil", help: "Edit") { onBeginEdit() }
            }
            iconButton("eye", help: "Quick Look (space)") {
                ClipboardQuickLook.shared.preview(item, store: store)
            }
            iconButton("trash", help: "Remove") { store.remove(item) }
        }
    }

    private func iconButton(_ systemName: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Palette.secondary)
                .frame(width: 20, height: 20)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Palette.separator)
                )
        }
        .buttonStyle(.plain)
        .help(help)
    }

    @ViewBuilder
    private var titleLine: some View {
        let expanded = (hovering || isSelected) && item.kind == .text
        let lineLimit = expanded ? 5 : 1
        let displayText: String = {
            if expanded, let full = item.text, !full.isEmpty {
                return item.title.map { "\($0)\n\(full)" } ?? full
            }
            return item.displayTitle
        }()
        Text(displayText)
            .font(.system(size: 11))
            .foregroundStyle(item.isStale ? Palette.tertiary : Palette.primary)
            .lineLimit(lineLimit)
            .truncationMode(.tail)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .animation(.easeOut(duration: 0.12), value: expanded)
    }

    // MARK: Editor

    @ViewBuilder
    private var editor: some View {
        ClipboardEditor(
            initialTitle: item.title ?? "",
            initialBody: item.text ?? item.preview,
            onCommit: { newTitle, newBody in
                store.updateTextItem(item, newTitle: newTitle, newText: newBody)
                onEndEdit()
            },
            onCancel: onEndEdit
        )
    }

    // MARK: Icon + secondary

    @ViewBuilder
    private var iconBadge: some View {
        switch item.kind {
        case .text:
            Image(systemName: "text.alignleft")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Palette.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Palette.separator)
                )
        case .image:
            if let url = store.imageURL(for: item),
               let image = NSImage(contentsOf: url) {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 22, height: 22)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.secondary)
            }
        case .file:
            if let url = item.resolvedURL {
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "questionmark.app.dashed")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.tertiary)
            }
        }
    }

    private var secondaryLine: String {
        let stamp = relativeStamp(item.addedAt)
        switch item.kind {
        case .text:
            if let t = item.text {
                return "\(t.count) char\(t.count == 1 ? "" : "s") \u{00B7} \(stamp)"
            }
            return stamp
        case .image:
            if let w = item.imageWidth, let h = item.imageHeight {
                return "\(w)\u{00D7}\(h) \u{00B7} \(stamp)"
            }
            return "Image \u{00B7} \(stamp)"
        case .file:
            if let bytes = item.byteSize {
                return "\(byteFormatter.string(fromByteCount: bytes)) \u{00B7} \(stamp)"
            }
            return stamp
        }
    }

    @ViewBuilder
    private var contextMenu: some View {
        Button("Copy") { store.copyToPasteboard(item) }
        Button(item.isPinned ? "Unpin" : "Pin") { store.togglePin(item) }
        if item.kind == .text {
            Button("Edit\u{2026}") { onBeginEdit() }
        }
        if item.kind == .image, let ocr = item.ocrText, !ocr.isEmpty {
            Divider()
            Button("Copy text from image") {
                let pb = NSPasteboard.general
                pb.clearContents()
                pb.setString(ocr, forType: .string)
            }
            Button("Save text as new entry") {
                store.acceptText(ocr)
            }
        }
        Button("Quick Look") { ClipboardQuickLook.shared.preview(item, store: store) }
        if item.kind == .file, let url = item.resolvedURL {
            Divider()
            Button("Reveal in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }
        }
        Divider()
        Button("Remove", role: .destructive) { store.remove(item) }
    }

    private func dragProvider() -> NSItemProvider {
        switch item.kind {
        case .text:
            return NSItemProvider(object: (item.text ?? item.preview) as NSString)
        case .image:
            if let url = store.imageURL(for: item) {
                return NSItemProvider(contentsOf: url) ?? NSItemProvider()
            }
            return NSItemProvider()
        case .file:
            if let url = item.resolvedURL {
                return NSItemProvider(object: url as NSURL)
            }
            return NSItemProvider()
        }
    }
}

// MARK: - Inline editor

private struct ClipboardEditor: View {
    @State var title: String
    @State var text: String
    let onCommit: (String?, String) -> Void
    let onCancel: () -> Void
    @FocusState private var bodyFocused: Bool

    init(initialTitle: String,
         initialBody: String,
         onCommit: @escaping (String?, String) -> Void,
         onCancel: @escaping () -> Void) {
        _title = State(initialValue: initialTitle)
        _text = State(initialValue: initialBody)
        self.onCommit = onCommit
        self.onCancel = onCancel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField("Title (optional)", text: $title)
                .textFieldStyle(.plain)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Palette.primary)
            TextEditor(text: $text)
                .scrollContentBackground(.hidden)
                .font(.system(size: 11))
                .foregroundStyle(Palette.primary)
                .frame(minHeight: 60, maxHeight: 100)
                .focused($bodyFocused)
            HStack(spacing: 6) {
                Spacer()
                Button("Cancel", action: onCancel)
                    .buttonStyle(.plain)
                    .font(.system(size: 10))
                    .foregroundStyle(Palette.secondary)
                Button("Save") {
                    onCommit(title.isEmpty ? nil : title, text)
                }
                .buttonStyle(.plain)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Palette.primary)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Palette.highlight)
                )
            }
        }
        .onAppear { bodyFocused = true }
    }
}

// MARK: - Helpers

private let byteFormatter: ByteCountFormatter = {
    let f = ByteCountFormatter()
    f.allowedUnits = [.useKB, .useMB, .useGB]
    f.countStyle = .file
    return f
}()

private let relativeFormatter: RelativeDateTimeFormatter = {
    let f = RelativeDateTimeFormatter()
    f.unitsStyle = .abbreviated
    return f
}()

private func relativeStamp(_ date: Date) -> String {
    let interval = -date.timeIntervalSinceNow
    if interval < 5 { return "just now" }
    return relativeFormatter.localizedString(for: date, relativeTo: Date())
}
