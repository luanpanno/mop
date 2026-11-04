import Foundation

/// A kind of junk Mop can clean, e.g. "User caches" or "Xcode DerivedData".
public struct CleanupCategory: Identifiable, Hashable, Sendable {
    public enum Removal: Sendable, Hashable {
        /// Move items to the Trash (default).
        case trash
        /// Delete permanently. Only used for "Empty Trash".
        case permanent
    }

    public let id: String
    public let name: String
    public let detail: String
    public let symbol: String
    /// Whether the scheduled auto-clean is allowed to clean it unattended.
    public let isSafeForAutoClean: Bool
    public let removal: Removal
    /// Folders whose *children* are the removable items.
    public let folders: [URL]
    /// Children that belong to another category (or must be kept).
    public let excluded: Set<URL>
    /// Children whose name starts with one of these prefixes are skipped (e.g. "com.apple.").
    public let excludedNamePrefixes: [String]

    public init(id: String, name: String, detail: String, symbol: String, isSafeForAutoClean: Bool,
                removal: Removal = .trash, folders: [URL], excluded: Set<URL> = [], excludedNamePrefixes: [String] = []) {
        self.id = id
        self.name = name
        self.detail = detail
        self.symbol = symbol
        self.isSafeForAutoClean = isSafeForAutoClean
        self.removal = removal
        self.folders = folders
        self.excluded = excluded
        self.excludedNamePrefixes = excludedNamePrefixes
    }
}

public struct CleanupResult: Identifiable, Sendable {
    public var id: String { category.id }
    public let category: CleanupCategory
    public let items: [FileItem]
    public var total: Int64 { items.totalSize }

    public init(category: CleanupCategory, items: [FileItem]) {
        self.category = category
        self.items = items
    }
}

public enum CleanupCatalog {
    public static func all(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> [CleanupCategory] {
        let lib = home.appendingPathComponent("Library")
        let caches = lib.appendingPathComponent("Caches")
        let developer = lib.appendingPathComponent("Developer")

        let browserCacheFolders = [
            "Google", "com.google.Chrome", "Firefox", "Mozilla", "com.apple.Safari", "BraveSoftware",
            "Microsoft Edge", "com.microsoft.edgemac", "com.operasoftware.Opera", "company.thebrowser.Browser", "Arc",
        ].map { caches.appendingPathComponent($0) }

        let packageCacheInCaches = ["Homebrew", "pip", "Yarn", "pnpm", "CocoaPods", "org.swift.swiftpm", "go-build"]
            .map { caches.appendingPathComponent($0) }

        // Mop's own cache and caches the system actively relies on are never offered.
        let keepInCaches: [URL] = [
            caches.appendingPathComponent("com.luanpanno.mop"),
            caches.appendingPathComponent("CloudKit"),
            caches.appendingPathComponent("com.apple.HomeKit"),
            caches.appendingPathComponent("FamilyCircle"),
        ]

        return [
            CleanupCategory(
                id: "userCaches", name: "App caches",
                detail: "Temporary files apps rebuild automatically.",
                symbol: "internaldrive", isSafeForAutoClean: true,
                folders: [caches],
                excluded: Set(browserCacheFolders + packageCacheInCaches + keepInCaches),
                // Apple's own caches are often privacy-protected (reading them triggers permission
                // prompts such as Apple Music access) and the system manages them itself.
                excludedNamePrefixes: ["com.apple."]
            ),
            CleanupCategory(
                id: "logs", name: "Logs",
                detail: "Diagnostic logs written by apps.",
                symbol: "doc.text", isSafeForAutoClean: true,
                folders: [lib.appendingPathComponent("Logs")]
            ),
            CleanupCategory(
                id: "browserCaches", name: "Browser caches",
                detail: "Cached web pages and images. Sites may load slower once.",
                symbol: "globe", isSafeForAutoClean: true,
                folders: browserCacheFolders
            ),
            CleanupCategory(
                id: "packageCaches", name: "Package manager caches",
                detail: "Homebrew, npm, pip, Yarn, pnpm, CocoaPods and SwiftPM downloads.",
                symbol: "shippingbox", isSafeForAutoClean: true,
                folders: packageCacheInCaches + [
                    home.appendingPathComponent(".npm/_cacache"),
                    home.appendingPathComponent(".cache/pip"),
                    home.appendingPathComponent(".gradle/caches"),
                ]
            ),
            CleanupCategory(
                id: "xcodeDerivedData", name: "Xcode DerivedData",
                detail: "Build products and indexes. Xcode rebuilds them.",
                symbol: "hammer", isSafeForAutoClean: true,
                folders: [developer.appendingPathComponent("Xcode/DerivedData")]
            ),
            CleanupCategory(
                id: "xcodeDeviceSupport", name: "Xcode device support",
                detail: "Debug symbols for devices you connected. Re-downloaded when needed.",
                symbol: "iphone", isSafeForAutoClean: false,
                folders: ["iOS DeviceSupport", "watchOS DeviceSupport", "tvOS DeviceSupport", "visionOS DeviceSupport"]
                    .map { developer.appendingPathComponent("Xcode/\($0)") }
            ),
            CleanupCategory(
                id: "simulatorCaches", name: "Simulator caches",
                detail: "CoreSimulator caches and logs.",
                symbol: "ipad.and.iphone", isSafeForAutoClean: true,
                folders: [developer.appendingPathComponent("CoreSimulator/Caches")]
            ),
            CleanupCategory(
                id: "xcodeArchives", name: "Xcode archives",
                detail: "Old app archives. Keep the ones you may need to symbolicate crashes.",
                symbol: "archivebox", isSafeForAutoClean: false,
                folders: [developer.appendingPathComponent("Xcode/Archives")]
            ),
            CleanupCategory(
                id: "trash", name: "Trash",
                detail: "Permanently deletes everything in the Trash.",
                symbol: "trash", isSafeForAutoClean: false, removal: .permanent,
                folders: [home.appendingPathComponent(".Trash")]
            ),
        ]
    }
}

public enum CleanupScanner {
    public static func scan(_ category: CleanupCategory) async -> CleanupResult {
        var items: [FileItem] = []
        for folder in category.folders {
            items += await DirectorySizer.sizedChildren(
                of: folder, excluding: category.excluded, excludingNamePrefixes: category.excludedNamePrefixes
            )
        }
        return CleanupResult(category: category, items: items.sorted { $0.size > $1.size })
    }

    public static func scan(_ categories: [CleanupCategory]) async -> [CleanupResult] {
        await withTaskGroup(of: CleanupResult.self) { group in
            for category in categories { group.addTask { await scan(category) } }
            var results: [CleanupResult] = []
            for await result in group { results.append(result) }
            let order = categories.map(\.id)
            return results.sorted { order.firstIndex(of: $0.id)! < order.firstIndex(of: $1.id)! }
        }
    }
}
