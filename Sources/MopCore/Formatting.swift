import Foundation

public extension Int64 {
    /// Human readable size, e.g. "1.2 GB".
    var formattedBytes: String {
        ByteCountFormatter.string(fromByteCount: self, countStyle: .file)
    }
}
