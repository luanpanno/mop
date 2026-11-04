import AppKit

public enum FullDiskAccess {
    /// True when Mop can read TCC-protected locations. There is no API for this, so we probe.
    public static var isGranted: Bool {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let probes = [
            home.appendingPathComponent("Library/Safari"),
            home.appendingPathComponent("Library/Containers/com.apple.stocks"),
            URL(fileURLWithPath: "/Library/Application Support/com.apple.TCC"),
        ]
        for probe in probes where FileManager.default.fileExists(atPath: probe.path) {
            if (try? FileManager.default.contentsOfDirectory(atPath: probe.path)) != nil { return true }
        }
        return false
    }

    public static let settingsURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!

    @MainActor
    public static func openSettings() {
        NSWorkspace.shared.open(settingsURL)
    }
}
