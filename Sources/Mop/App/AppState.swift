import AppKit
import MopCore
import Observation

enum SidebarSection: String, CaseIterable, Identifiable, Hashable {
    case overview, uninstaller, cleanup, largeFiles

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: "Overview"
        case .uninstaller: "Uninstaller"
        case .cleanup: "Cleanup"
        case .largeFiles: "Large Files"
        }
    }

    var symbol: String {
        switch self {
        case .overview: "chart.pie"
        case .uninstaller: "xmark.app"
        case .cleanup: "sparkles"
        case .largeFiles: "doc.on.doc"
        }
    }
}

/// An app that was deleted outside Mop and left files behind.
struct OrphanedApp: Identifiable {
    let id = UUID()
    let name: String
    let leftovers: [Leftover]
    var total: Int64 { leftovers.reduce(0) { $0 + $1.size } }
}

/// Shared state for the main window and the menu bar popover.
@Observable
@MainActor
final class AppState {
    var section: SidebarSection = .overview

    // Disk
    var disk: DiskInfo?
    var locationBreakdown: [FileItem] = []
    var isAnalyzingLocations = false

    // Cleanup
    var cleanupResults: [CleanupResult] = []
    var isScanningCleanup = false
    var lastCleanupScan: Date?
    var reclaimable: Int64 = 0

    // Apps
    var apps: [InstalledApp] = []
    var isScanningApps = false
    /// Apps Mop itself removed; the removal watcher ignores them.
    var recentlyUninstalled: Set<URL> = []
    var orphans: [OrphanedApp] = []

    // Permissions
    var hasFullDiskAccess = FullDiskAccess.isGranted
    var showOnboarding = false

    init() {
        let defaults = UserDefaults.standard
        reclaimable = Int64(defaults.integer(forKey: Prefs.Key.lastReclaimableBytes))
        lastCleanupScan = defaults.object(forKey: Prefs.Key.lastCleanupScan) as? Date
    }

    // MARK: Disk

    func refreshDisk() {
        disk = try? DiskInfoService.current()
    }

    func analyzeLocations() async {
        guard !isAnalyzingLocations else { return }
        isAnalyzingLocations = true
        defer { isAnalyzingLocations = false }
        let home = FileManager.default.homeDirectoryForCurrentUser
        let candidates = [URL(fileURLWithPath: "/Applications")] + [
            "Documents", "Downloads", "Desktop", "Movies", "Music", "Pictures", "Library", "Developer", "Applications",
        ].map { home.appendingPathComponent($0) }
        let existing = candidates.filter { FileManager.default.fileExists(atPath: $0.path) }
        let sizes = await DirectorySizer.sizes(of: existing)
        locationBreakdown = existing
            .map { FileItem(url: $0, size: sizes[$0] ?? 0) }
            .filter { $0.size > 0 }
            .sorted { $0.size > $1.size }
    }

    // MARK: Cleanup

    func scanCleanup() async {
        guard !isScanningCleanup else { return }
        isScanningCleanup = true
        defer { isScanningCleanup = false }
        cleanupResults = await CleanupScanner.scan(CleanupCatalog.all())
        reclaimable = cleanupResults.reduce(0) { $0 + $1.total }
        lastCleanupScan = Date()
        UserDefaults.standard.set(Int(reclaimable), forKey: Prefs.Key.lastReclaimableBytes)
        UserDefaults.standard.set(lastCleanupScan, forKey: Prefs.Key.lastCleanupScan)
        refreshDisk()
    }

    /// Cleans the given categories. Trash-category items are deleted permanently; everything else goes to the Trash.
    func clean(_ results: [CleanupResult]) async -> RemovalReport {
        let toTrash = results.filter { $0.category.removal == .trash }.flatMap(\.items)
        let toDelete = results.filter { $0.category.removal == .permanent }.flatMap(\.items)
        var report = await TrashService.moveToTrash(toTrash)
        if !toDelete.isEmpty {
            let deleted = TrashService.emptyTrash(toDelete)
            report.removed += deleted.removed
            report.failed += deleted.failed
        }
        await scanCleanup()
        return report
    }

    // MARK: Apps

    func scanApps() async {
        guard !isScanningApps else { return }
        isScanningApps = true
        defer { isScanningApps = false }
        apps = await InstalledAppScanner().scan()
    }

    func leftovers(for app: InstalledApp) async -> [Leftover] {
        await Task.detached(priority: .userInitiated) {
            LeftoverFinder.standard().find(for: app)
        }.value
    }

    func leftovers(bundleID: String?, name: String, teamID: String?) async -> [Leftover] {
        await Task.detached(priority: .utility) {
            LeftoverFinder.standard().find(bundleID: bundleID, appName: name, teamID: teamID)
        }.value
    }

    func uninstall(_ app: InstalledApp, includeApp: Bool, leftovers: [Leftover]) async -> RemovalReport {
        var items = leftovers.map { FileItem(url: $0.url, size: $0.size) }
        if includeApp {
            items.insert(FileItem(url: app.url, size: app.size), at: 0)
            recentlyUninstalled.insert(app.url)
        }
        let report = await TrashService.moveToTrash(items)
        if report.removed.contains(where: { $0.url == app.url }) {
            apps.removeAll { $0.url == app.url }
        }
        refreshDisk()
        return report
    }

    func trash(_ items: [FileItem]) async -> RemovalReport {
        let report = await TrashService.moveToTrash(items)
        refreshDisk()
        return report
    }

    func refreshPermissions() {
        hasFullDiskAccess = FullDiskAccess.isGranted
    }
}
