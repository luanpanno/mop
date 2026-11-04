import AppKit

/// Result of a removal operation.
public struct RemovalReport: Sendable {
    public var removed: [FileItem] = []
    public var failed: [(item: FileItem, reason: String)] = []

    public init() {}

    public var bytesRemoved: Int64 { removed.totalSize }
    public var isSuccess: Bool { failed.isEmpty }
}

/// Moves items to the Trash after checking them with `SafetyGuard`.
@MainActor
public enum TrashService {
    public static func moveToTrash(_ items: [FileItem], guard safety: SafetyGuard = SafetyGuard()) async -> RemovalReport {
        var report = RemovalReport()
        var needsPrivileges: [FileItem] = []

        for item in items {
            if case .blocked(let reason) = safety.check(item.url) {
                report.failed.append((item, reason))
                continue
            }
            guard FileManager.default.fileExists(atPath: item.url.path) else {
                report.removed.append(item) // already gone
                continue
            }
            do {
                try FileManager.default.trashItem(at: item.url, resultingItemURL: nil)
                report.removed.append(item)
            } catch let error as CocoaError where error.code == .fileWriteNoPermission {
                needsPrivileges.append(item)
            } catch {
                report.failed.append((item, error.localizedDescription))
            }
        }

        // Root-owned items (e.g. apps installed by an admin, /Library helpers):
        // NSWorkspace.recycle goes through Finder, which asks for an administrator password.
        if !needsPrivileges.isEmpty {
            let recycled = await recycle(needsPrivileges.map(\.url))
            for item in needsPrivileges {
                if recycled.contains(item.url) || !FileManager.default.fileExists(atPath: item.url.path) {
                    report.removed.append(item)
                } else {
                    report.failed.append((item, "Permission denied"))
                }
            }
        }

        RemovalLog.append(report)
        return report
    }

    private static func recycle(_ urls: [URL]) async -> Set<URL> {
        await withCheckedContinuation { continuation in
            NSWorkspace.shared.recycle(urls) { newURLs, _ in
                continuation.resume(returning: Set(newURLs.keys))
            }
        }
    }

    /// Permanently deletes the contents of the user's Trash. Only called after explicit confirmation.
    public static func emptyTrash(_ items: [FileItem]) -> RemovalReport {
        var report = RemovalReport()
        let trash = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".Trash").standardizedFileURL.path
        for item in items {
            guard item.url.standardizedFileURL.path.hasPrefix(trash + "/") else {
                report.failed.append((item, "Not in the Trash"))
                continue
            }
            do {
                try FileManager.default.removeItem(at: item.url)
                report.removed.append(item)
            } catch {
                report.failed.append((item, error.localizedDescription))
            }
        }
        RemovalLog.append(report, permanent: true)
        return report
    }
}

/// Append-only log of everything Mop removed, in ~/Library/Application Support/Mop/removals.log.
public enum RemovalLog {
    public static var folder: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Mop", isDirectory: true)
    }

    public static func append(_ report: RemovalReport, permanent: Bool = false) {
        guard !report.removed.isEmpty || !report.failed.isEmpty else { return }
        let date = ISO8601DateFormatter().string(from: Date())
        var lines = report.removed.map { "\(date)\t\(permanent ? "deleted" : "trashed")\t\($0.size)\t\($0.url.path)" }
        lines += report.failed.map { "\(date)\tfailed\t\($0.item.size)\t\($0.item.url.path)\t\($0.reason)" }
        let data = Data((lines.joined(separator: "\n") + "\n").utf8)
        let file = folder.appendingPathComponent("removals.log")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        if let handle = try? FileHandle(forWritingTo: file) {
            handle.seekToEndOfFile()
            handle.write(data)
            try? handle.close()
        } else {
            try? data.write(to: file)
        }
    }
}
