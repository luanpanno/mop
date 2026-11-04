import Foundation

/// A temporary folder that is deleted when the value is deinitialized.
final class TempDir {
    let url: URL

    init() {
        url = FileManager.default.temporaryDirectory.appendingPathComponent("MopTests-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: url)
    }

    @discardableResult
    func file(_ path: String, bytes: Int = 10, fill: UInt8 = 1) -> URL {
        let file = url.appendingPathComponent(path)
        try! FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try! Data(repeating: fill, count: bytes).write(to: file)
        return file
    }

    @discardableResult
    func dir(_ path: String) -> URL {
        let dir = url.appendingPathComponent(path)
        try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
