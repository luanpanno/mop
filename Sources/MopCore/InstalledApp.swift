import AppKit
import CoreServices
import Security

/// An application bundle found on disk.
public struct InstalledApp: Identifiable, Hashable, Sendable {
    public var id: URL { url }
    public let url: URL
    public let name: String
    public let bundleID: String?
    public let version: String?
    public let teamID: String?
    public var size: Int64
    public var lastUsed: Date?

    public init(url: URL, name: String, bundleID: String?, version: String?, teamID: String?, size: Int64, lastUsed: Date?) {
        self.url = url
        self.name = name
        self.bundleID = bundleID
        self.version = version
        self.teamID = teamID
        self.size = size
        self.lastUsed = lastUsed
    }

    public var isAppleApp: Bool { bundleID?.lowercased().hasPrefix("com.apple.") ?? false }

    /// Reads bundle metadata (no size). Returns nil when the URL is not an app bundle.
    public static func metadata(at url: URL) -> InstalledApp? {
        guard url.pathExtension == "app", let bundle = Bundle(url: url) else { return nil }
        let info = bundle.infoDictionary ?? [:]
        let name = (info["CFBundleDisplayName"] as? String)
            ?? (info["CFBundleName"] as? String)
            ?? url.deletingPathExtension().lastPathComponent
        return InstalledApp(
            url: url,
            name: name,
            bundleID: bundle.bundleIdentifier,
            version: info["CFBundleShortVersionString"] as? String,
            teamID: teamIdentifier(of: url),
            size: 0,
            lastUsed: SpotlightMetadata.lastUsedDate(of: url)
        )
    }

    static func teamIdentifier(of url: URL) -> String? {
        var staticCode: SecStaticCode?
        guard SecStaticCodeCreateWithPath(url as CFURL, [], &staticCode) == errSecSuccess, let code = staticCode else { return nil }
        var info: CFDictionary?
        guard SecCodeCopySigningInformation(code, SecCSFlags(rawValue: kSecCSSigningInformation), &info) == errSecSuccess,
              let dict = info as? [String: Any] else { return nil }
        return dict[kSecCodeInfoTeamIdentifier as String] as? String
    }
}

public enum SpotlightMetadata {
    /// "Last opened" date as tracked by Spotlight, if any.
    public static func lastUsedDate(of url: URL) -> Date? {
        guard let item = MDItemCreateWithURL(nil, url as CFURL) else { return nil }
        return MDItemCopyAttribute(item, kMDItemLastUsedDate) as? Date
    }
}

/// Finds installed applications in the standard application folders.
public struct InstalledAppScanner: Sendable {
    public var roots: [URL]

    public init(roots: [URL]? = nil) {
        let home = FileManager.default.homeDirectoryForCurrentUser
        self.roots = roots ?? [
            URL(fileURLWithPath: "/Applications"),
            home.appendingPathComponent("Applications"),
        ]
    }

    /// App bundle URLs, looking one folder deep (e.g. /Applications/Utilities, vendor folders).
    public func appURLs() -> [URL] {
        let fm = FileManager.default
        var result: [URL] = []
        for root in roots {
            guard let children = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else { continue }
            for child in children {
                if child.pathExtension == "app" {
                    result.append(child)
                } else if (try? child.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true,
                          let nested = try? fm.contentsOfDirectory(at: child, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
                    result.append(contentsOf: nested.filter { $0.pathExtension == "app" })
                }
            }
        }
        return result
    }

    /// Scans every app with metadata and size. Apple's own apps are excluded.
    public func scan() async -> [InstalledApp] {
        let urls = appURLs()
        return await withTaskGroup(of: InstalledApp?.self) { group in
            for url in urls {
                group.addTask {
                    guard var app = InstalledApp.metadata(at: url), !app.isAppleApp else { return nil }
                    app.size = DirectorySizer.size(of: url)
                    return app
                }
            }
            var apps: [InstalledApp] = []
            for await app in group { if let app { apps.append(app) } }
            return apps.sorted { $0.size > $1.size }
        }
    }
}
