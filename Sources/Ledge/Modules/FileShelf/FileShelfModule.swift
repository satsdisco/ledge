import SwiftUI
import AppKit
import UniformTypeIdentifiers

final class FileShelfModule: LedgeModule {
    static let identifier = "com.satsdisco.ledge.module.fileshelf"
    let displayName = "File Shelf"
    var acceptsDrops: Bool { true }

    let store = FileShelfStore()
    private let env: ModuleEnvironment

    init(environment: ModuleEnvironment) {
        self.env = environment
        store.load()
    }

    // MARK: - Views

    var collapsedView: AnyView {
        AnyView(FileShelfCollapsedView(store: store))
    }

    var expandedView: AnyView {
        AnyView(FileShelfExpandedView(store: store))
    }

    // MARK: - Drop handling

    func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        let group = DispatchGroup()
        var collected: [URL] = []
        let lock = NSLock()

        for provider in providers {
            guard provider.canLoadObject(ofClass: URL.self) else { continue }
            group.enter()
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                defer { group.leave() }
                guard let url else { return }
                lock.lock()
                collected.append(url)
                lock.unlock()
            }
        }

        group.notify(queue: .main) { [weak self] in
            self?.store.accept(urls: collected)
        }
        return true
    }

    func didActivate()    {}
    func willDeactivate() {}
}
