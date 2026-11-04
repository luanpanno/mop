import Foundation

/// A file or folder that belongs to an app outside its bundle.
public struct Leftover: Identifiable, Hashable, Sendable {
    public enum Confidence: Sendable, Hashable {
        /// Name matches the bundle identifier: safe to preselect.
        case exact
        /// Name only matches the app's display name or team: shown unchecked.
        case possible
    }

    public var id: URL { url }
    public let url: URL
    public let size: Int64
    public let confidence: Confidence

    public init(url: URL, size: Int64, confidence: Confidence) {
        self.url = url
        self.size = size
        self.confidence = confidence
    }

    /// Parent folder name, e.g. "Caches" or "Application Support".
    public var location: String { url.deletingLastPathComponent().lastPathComponent }
}

/// Locates files an app leaves behind in the Library folders.
public struct LeftoverFinder: Sendable {
    public var searchRoots: [URL]

    public init(searchRoots: [URL]) {
        self.searchRoots = searchRoots
    }

    public static func standard(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> LeftoverFinder {
        let userLibrary = home.appendingPathComponent("Library")
        let userFolders = [
            "Application Support", "Application Scripts", "Caches", "Containers", "Group Containers",
            "Preferences", "Saved Application State", "Logs", "HTTPStorages", "WebKit",
            "LaunchAgents", "Cookies",
        ].map { userLibrary.appendingPathComponent($0) }
        let systemLibrary = URL(fileURLWithPath: "/Library")
        let systemFolders = [
            "Application Support", "Caches", "Preferences", "LaunchAgents", "LaunchDaemons", "PrivilegedHelperTools", "Logs",
        ].map { systemLibrary.appendingPathComponent($0) }
        return LeftoverFinder(searchRoots: userFolders + systemFolders)
    }

    public func find(bundleID: String?, appName: String, teamID: String? = nil) -> [Leftover] {
        let fm = FileManager.default
        var matches: [(URL, Leftover.Confidence)] = []
        for root in searchRoots {
            guard let children = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil, options: []) else { continue }
            for child in children {
                if let confidence = Self.match(name: child.lastPathComponent, bundleID: bundleID, appName: appName, teamID: teamID) {
                    matches.append((child, confidence))
                }
            }
        }
        return matches
            .map { Leftover(url: $0.0, size: DirectorySizer.size(of: $0.0), confidence: $0.1) }
            .sorted { ($0.confidence == .exact ? 0 : 1, -$0.size) < ($1.confidence == .exact ? 0 : 1, -$1.size) }
    }

    public func find(for app: InstalledApp) -> [Leftover] {
        find(bundleID: app.bundleID, appName: app.name, teamID: app.teamID)
    }

    /// Decides whether a Library entry named `name` belongs to the app.
    static func match(name rawName: String, bundleID: String?, appName: String, teamID: String?) -> Leftover.Confidence? {
        let name = rawName.lowercased()
        if let bundleID = bundleID?.lowercased(), !bundleID.isEmpty {
            // com.foo.app, com.foo.app.plist, com.foo.app.savedState, com.foo.app.helper,
            // TEAMID.com.foo.app (group containers), group.com.foo.app
            if name == bundleID || name.hasPrefix(bundleID + ".") { return .exact }
            if name.hasSuffix("." + bundleID) || name.contains("." + bundleID + ".") { return .exact }
        }
        let normalizedApp = normalize(appName)
        if normalizedApp.count >= 3 {
            let stem = normalize((rawName as NSString).deletingPathExtension)
            if stem == normalizedApp { return .possible }
        }
        if let teamID = teamID?.lowercased(), !teamID.isEmpty, name.hasPrefix(teamID + ".") {
            return .possible
        }
        return nil
    }

    static func normalize(_ string: String) -> String {
        string.lowercased().filter { $0.isLetter || $0.isNumber }
    }
}
