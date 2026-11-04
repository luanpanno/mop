import Foundation

/// Last line of defense: decides whether Mop may ever remove a path.
public struct SafetyGuard: Sendable {
    public enum Verdict: Equatable, Sendable {
        case allowed
        case blocked(String)
    }

    public var home: URL
    public var ownBundle: URL?

    public init(home: URL = FileManager.default.homeDirectoryForCurrentUser, ownBundle: URL? = Bundle.main.bundleURL) {
        self.home = home.standardizedFileURL
        self.ownBundle = ownBundle?.standardizedFileURL
    }

    private static let blockedPrefixes = [
        "/System", "/usr", "/bin", "/sbin", "/private/var/db", "/Library/Apple", "/Library/Frameworks",
        "/Library/Extensions", "/Library/Filesystems", "/cores", "/dev", "/Volumes",
    ]

    /// Folders that may contain removable things but must never be removed themselves.
    private var protectedFolders: Set<String> {
        let h = home.path
        var set: Set<String> = [
            "/", "/Applications", "/Library", "/Users", "/private", "/private/var", "/private/tmp", "/opt",
            h, "\(h)/Library", "\(h)/Applications", "\(h)/Desktop", "\(h)/Documents", "\(h)/Downloads",
            "\(h)/Movies", "\(h)/Music", "\(h)/Pictures", "\(h)/Public", "\(h)/.Trash",
            "\(h)/Library/Mobile Documents",
        ]
        for name in ["Application Support", "Application Scripts", "Caches", "Containers", "Group Containers",
                     "Preferences", "Saved Application State", "Logs", "HTTPStorages", "WebKit",
                     "LaunchAgents", "LaunchDaemons", "Cookies", "PrivilegedHelperTools", "Developer"] {
            set.insert("\(h)/Library/\(name)")
            set.insert("/Library/\(name)")
        }
        return set
    }

    public func check(_ url: URL) -> Verdict {
        let path = url.standardizedFileURL.resolvingSymlinksInPath().path
        let rawPath = url.standardizedFileURL.path

        if protectedFolders.contains(path) || protectedFolders.contains(rawPath) {
            return .blocked("\(url.lastPathComponent) is a protected folder")
        }
        for prefix in Self.blockedPrefixes where path == prefix || path.hasPrefix(prefix + "/") {
            return .blocked("\(url.lastPathComponent) is part of macOS")
        }
        if let ownBundle, path == ownBundle.path || path.hasPrefix(ownBundle.path + "/") {
            return .blocked("Mop can't remove itself")
        }
        if url.pathExtension == "app", let bundleID = Bundle(url: url)?.bundleIdentifier,
           bundleID.lowercased().hasPrefix("com.apple.") {
            return .blocked("\(url.lastPathComponent) is an Apple app")
        }
        return .allowed
    }
}
