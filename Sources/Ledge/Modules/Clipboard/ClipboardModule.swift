import SwiftUI
import AppKit
import UniformTypeIdentifiers

final class ClipboardModule: LedgeModule {
    static let identifier = "com.satsdisco.ledge.module.clipboard"
    let displayName = "Clipboard"
    let iconName = "doc.on.clipboard"
    var acceptsDrops: Bool { true }
    var wantsKeyboardFocus: Bool { true }

    let store = ClipboardStore()
    private let env: ModuleEnvironment

    init(environment: ModuleEnvironment) {
        self.env = environment
        store.load()
        store.ensureSelectionValid()
        // After any copy-to-pasteboard, collapse the panel so the user can
        // immediately ⌘V into whatever app they were just using.
        let expansion = environment.expansion
        store.onAfterCopy = { [weak expansion] in
            expansion?.collapse()
        }
    }

    var collapsedView: AnyView {
        AnyView(ClipboardCollapsedView(store: store))
    }

    var expandedView: AnyView {
        AnyView(ClipboardExpandedView(store: store))
    }

    var preferredExpandedSize: CGSize { CGSize(width: 540, height: 300) }

    /// Captures the system clipboard contents into the stash. Wired to a
    /// global hotkey by `KeyboardShortcutCenter`.
    @discardableResult
    func captureFromSystemClipboard() -> ClipboardStore.CaptureResult {
        store.captureFromPasteboard()
    }

    func didActivate() {
        store.ensureSelectionValid()
    }

    func willDeactivate() {}

    // MARK: - Drop handling

    func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        let group = DispatchGroup()
        var fileURLs: [URL] = []
        var images: [NSImage] = []
        var strings: [String] = []
        let lock = NSLock()

        for provider in providers {
            if provider.canLoadObject(ofClass: URL.self) {
                group.enter()
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    defer { group.leave() }
                    guard let url else { return }
                    lock.lock()
                    if url.isFileURL { fileURLs.append(url) } else { strings.append(url.absoluteString) }
                    lock.unlock()
                }
                continue
            }
            if provider.canLoadObject(ofClass: NSImage.self) {
                group.enter()
                _ = provider.loadObject(ofClass: NSImage.self) { image, _ in
                    defer { group.leave() }
                    guard let image = image as? NSImage else { return }
                    lock.lock(); images.append(image); lock.unlock()
                }
                continue
            }
            if provider.canLoadObject(ofClass: NSString.self) {
                group.enter()
                _ = provider.loadObject(ofClass: NSString.self) { string, _ in
                    defer { group.leave() }
                    guard let s = string as? String else { return }
                    lock.lock(); strings.append(s); lock.unlock()
                }
            }
        }

        group.notify(queue: .main) { [weak self] in
            guard let self else { return }
            for url in fileURLs { self.store.acceptFile(url) }
            for image in images { self.store.acceptImage(image) }
            for s in strings    { self.store.acceptText(s) }
        }
        return true
    }
}
