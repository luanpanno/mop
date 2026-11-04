import Foundation

/// Computes on-disk (allocated) sizes. All functions are synchronous and blocking;
/// call them from a background task. They stop early when the current task is cancelled.
public enum DirectorySizer {
    private static let keys: [URLResourceKey] = [
        .isRegularFileKey, .isDirectoryKey, .isSymbolicLinkKey,
        .totalFileAllocatedSizeKey, .fileAllocatedSizeKey,
    ]

    /// Size of a file, or the recursive size of a folder/package. Symlinks are not followed.
    public static func size(of url: URL) -> Int64 {
        guard let values = try? url.resourceValues(forKeys: Set(keys)) else { return 0 }
        if values.isSymbolicLink == true { return 0 }
        if values.isDirectory != true { return allocatedSize(values) }

        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: keys,
            options: [],
            errorHandler: { _, _ in true }
        ) else { return 0 }

        var total: Int64 = 0
        var counter = 0
        while let child = enumerator.nextObject() as? URL {
            counter += 1
            if counter % 2048 == 0, Task.isCancelled { return total }
            guard let v = try? child.resourceValues(forKeys: Set(keys)), v.isRegularFile == true else { continue }
            total += allocatedSize(v)
        }
        return total
    }

    /// Sizes many items concurrently.
    public static func sizes(of urls: [URL]) async -> [URL: Int64] {
        await withTaskGroup(of: (URL, Int64).self) { group in
            for url in urls {
                group.addTask { (url, size(of: url)) }
            }
            var result: [URL: Int64] = [:]
            for await (url, size) in group { result[url] = size }
            return result
        }
    }

    /// Immediate children of a folder (hidden ones included), sized concurrently,
    /// largest first. Missing or unreadable folders return an empty list.
    public static func sizedChildren(
        of folder: URL, excluding excluded: Set<URL> = [], excludingNamePrefixes prefixes: [String] = []
    ) async -> [FileItem] {
        let children = (try? FileManager.default.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: nil, options: []
        )) ?? []
        let standardizedExcluded = Set(excluded.map(\.standardizedFileURL))
        let candidates = children.filter { child in
            let name = child.lastPathComponent
            return name != ".DS_Store"
                && !standardizedExcluded.contains(child.standardizedFileURL)
                && !prefixes.contains { name.hasPrefix($0) }
        }
        let sizes = await sizes(of: candidates)
        return candidates
            .map { FileItem(url: $0, size: sizes[$0] ?? 0) }
            .filter { $0.size > 0 }
            .sorted { $0.size > $1.size }
    }

    static func allocatedSize(_ values: URLResourceValues) -> Int64 {
        Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
    }
}
