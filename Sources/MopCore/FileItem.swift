import Foundation

/// A file or folder on disk with its allocated size.
public struct FileItem: Identifiable, Hashable, Sendable {
    public var id: URL { url }
    public let url: URL
    public let size: Int64
    public var lastUsed: Date?
    public var modified: Date?

    public init(url: URL, size: Int64, lastUsed: Date? = nil, modified: Date? = nil) {
        self.url = url
        self.size = size
        self.lastUsed = lastUsed
        self.modified = modified
    }

    public var name: String { url.lastPathComponent }
}

public extension Sequence where Element == FileItem {
    var totalSize: Int64 { reduce(0) { $0 + $1.size } }
}
