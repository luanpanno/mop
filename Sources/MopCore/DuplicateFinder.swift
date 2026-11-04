import CryptoKit
import Foundation

/// Finds files with identical content: group by size, then by a hash of the first 64 KB, then by a full SHA-256.
public struct DuplicateFinder: Sendable {
    public var minimumSize: Int64

    public init(minimumSize: Int64 = 1_000_000) {
        self.minimumSize = minimumSize
    }

    /// Blocking: call from a background task. Each group is sorted oldest-first (the likely "original").
    public func scan(_ root: URL) -> [[FileItem]] {
        let keys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .contentModificationDateKey]
        guard let enumerator = FileManager.default.enumerator(
            at: root, includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants],
            errorHandler: { _, _ in true }
        ) else { return [] }

        var bySize: [Int: [FileItem]] = [:]
        var counter = 0
        while let url = enumerator.nextObject() as? URL {
            counter += 1
            if counter % 2048 == 0, Task.isCancelled { return [] }
            guard let v = try? url.resourceValues(forKeys: Set(keys)), v.isRegularFile == true,
                  let logical = v.fileSize, Int64(logical) >= minimumSize else { continue }
            let item = FileItem(url: url, size: DirectorySizer.allocatedSize(v), modified: v.contentModificationDate)
            bySize[logical, default: []].append(item)
        }
        return Self.group(bySize.values.filter { $0.count > 1 })
    }

    static func group(_ sameSizeGroups: [[FileItem]]) -> [[FileItem]] {
        var result: [[FileItem]] = []
        for candidates in sameSizeGroups {
            if Task.isCancelled { return result }
            let byPrefix = Dictionary(grouping: candidates) { hash($0.url, limit: 65_536) ?? UUID().uuidString }
            for prefixGroup in byPrefix.values where prefixGroup.count > 1 {
                let byFull = Dictionary(grouping: prefixGroup) { hash($0.url, limit: nil) ?? UUID().uuidString }
                for group in byFull.values where group.count > 1 {
                    result.append(group.sorted { ($0.modified ?? .distantPast) < ($1.modified ?? .distantPast) })
                }
            }
        }
        return result.sorted { wasted($0) > wasted($1) }
    }

    /// Bytes that would be freed by keeping one copy.
    public static func wasted(_ group: [FileItem]) -> Int64 {
        group.dropFirst().totalSize
    }

    static func hash(_ url: URL, limit: Int?) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        var hasher = SHA256()
        var remaining = limit ?? .max
        while remaining > 0 {
            let chunk = min(remaining, 1_048_576)
            guard let data = try? handle.read(upToCount: chunk), !data.isEmpty else { break }
            hasher.update(data: data)
            remaining -= data.count
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
