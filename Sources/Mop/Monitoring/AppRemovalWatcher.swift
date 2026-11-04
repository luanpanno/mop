import Foundation
import MopCore

/// Watches the application folders and reports apps that disappear (e.g. dragged to the Trash in Finder).
@MainActor
final class AppRemovalWatcher {
    private let scanner = InstalledAppScanner()
    private var sources: [DispatchSourceFileSystemObject] = []
    private var snapshot: [URL: InstalledApp] = [:]
    private var pendingCheck: Task<Void, Never>?
    var onAppRemoved: (InstalledApp) -> Void = { _ in }

    var isRunning: Bool { !sources.isEmpty }

    func start() {
        guard sources.isEmpty else { return }
        Task { snapshot = await Self.metadata(for: scanner.appURLs()) }

        for root in scanner.roots {
            let fd = open(root.path, O_EVTONLY)
            guard fd >= 0 else { continue }
            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: fd, eventMask: [.write, .delete, .rename, .link], queue: .main
            )
            source.setEventHandler { [weak self] in
                MainActor.assumeIsolated { self?.scheduleCheck() }
            }
            source.setCancelHandler { close(fd) }
            source.resume()
            sources.append(source)
        }
    }

    func stop() {
        sources.forEach { $0.cancel() }
        sources.removeAll()
        pendingCheck?.cancel()
    }

    private func scheduleCheck() {
        pendingCheck?.cancel()
        pendingCheck = Task {
            try? await Task.sleep(for: .seconds(2)) // debounce: Finder emits several events per move
            guard !Task.isCancelled else { return }
            await check()
        }
    }

    private func check() async {
        let current = Set(scanner.appURLs())
        let removed = snapshot.keys.filter { !current.contains($0) }
        let added = current.filter { snapshot[$0] == nil }

        for url in removed {
            if let app = snapshot.removeValue(forKey: url) { onAppRemoved(app) }
        }
        let newApps = await Self.metadata(for: Array(added))
        snapshot.merge(newApps) { _, new in new }
    }

    private static func metadata(for urls: [URL]) async -> [URL: InstalledApp] {
        await Task.detached(priority: .utility) {
            var result: [URL: InstalledApp] = [:]
            for url in urls {
                if let app = InstalledApp.metadata(at: url), !app.isAppleApp { result[url] = app }
            }
            return result
        }.value
    }
}
