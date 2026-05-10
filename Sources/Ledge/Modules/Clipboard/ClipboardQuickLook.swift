import AppKit
import Quartz

/// Drives the system Quick Look panel (the one Finder shows when you hit
/// space) for clipboard entries. Text entries are rendered to a temp .txt
/// file because QLPreviewItem requires a URL.
final class ClipboardQuickLook: NSObject, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    static let shared = ClipboardQuickLook()

    private var url: URL?
    private var tempURL: URL?

    func preview(_ item: ClipboardItem, store: ClipboardStore) {
        cleanupTempFile()
        switch item.kind {
        case .file:
            self.url = item.resolvedURL
        case .image:
            self.url = store.imageURL(for: item)
        case .text:
            self.url = makeTempTextFile(for: item)
            self.tempURL = self.url
        }

        guard let panel = QLPreviewPanel.shared() else { return }
        panel.dataSource = self
        panel.delegate = self
        if !panel.isVisible {
            panel.makeKeyAndOrderFront(nil)
        }
        panel.reloadData()
    }

    private func makeTempTextFile(for item: ClipboardItem) -> URL? {
        let body = item.text ?? item.preview
        let title = item.title?.replacingOccurrences(of: "/", with: "-") ?? "Clipboard"
        let safe = title.isEmpty ? "Clipboard" : title
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("Ledge-Clipboard")
        try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        let url = tmp.appendingPathComponent("\(safe).txt")
        do {
            try body.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            Log.module.error("QuickLook temp write failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private func cleanupTempFile() {
        if let temp = tempURL { try? FileManager.default.removeItem(at: temp) }
        tempURL = nil
    }

    // MARK: - QLPreviewPanelDataSource

    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        url == nil ? 0 : 1
    }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        url as NSURL?
    }
}
