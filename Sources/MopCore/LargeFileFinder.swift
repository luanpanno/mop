import Foundation

/// Finds big files, optionally only those not opened for a while.
public struct LargeFileFinder: Sendable {
    public var minimumSize: Int64
    /// When set, only files last used (or modified, if never opened) before this date are returned.
    public var unusedSince: Date?
    public var limit: Int

    public init(minimumSize: Int64 = 100_000_000, unusedSince: Date? = nil, limit: Int = 500) {
        self.minimumSize = minimumSize
        self.unusedSince = unusedSince
        self.limit = limit
    }

    /// Blocking: call from a background task.
    public func scan(_ root: URL) -> [FileItem] {
        let keys: [URLResourceKey] = [.isRegularFileKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .contentModificationDateKey]
        guard let enumerator = FileManager.default.enumerator(
            at: root, includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants],
            errorHandler: { _, _ in true }
        ) else { return [] }

        var found: [FileItem] = []
        var counter = 0
        while let url = enumerator.nextObject() as? URL {
            counter += 1
            if counter % 2048 == 0, Task.isCancelled { break }
            guard let values = try? url.resourceValues(forKeys: Set(keys)), values.isRegularFile == true else { continue }
            let size = DirectorySizer.allocatedSize(values)
            guard size >= minimumSize else { continue }
            let lastUsed = SpotlightMetadata.lastUsedDate(of: url)
            let item = FileItem(url: url, size: size, lastUsed: lastUsed, modified: values.contentModificationDate)
            if let unusedSince {
                let reference = lastUsed ?? values.contentModificationDate ?? .distantPast
                guard reference < unusedSince else { continue }
            }
            found.append(item)
        }
        return Array(found.sorted { $0.size > $1.size }.prefix(limit))
    }
}
