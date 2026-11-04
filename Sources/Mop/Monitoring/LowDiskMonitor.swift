import Foundation
import MopCore

/// Posts a notification when free space drops below the threshold set in Settings.
@MainActor
final class LowDiskMonitor {
    private var lastAlert: Date?
    private let repeatInterval: TimeInterval = 6 * 3600

    func evaluate(_ disk: DiskInfo?) {
        let defaults = UserDefaults.standard
        guard let disk, defaults.bool(forKey: Prefs.Key.lowDiskAlertsEnabled) else { return }
        let threshold = Int64(defaults.integer(forKey: Prefs.Key.lowDiskThresholdGB)) * 1_000_000_000
        guard disk.availableForImportantUsage < threshold else {
            lastAlert = nil
            return
        }
        if let lastAlert, Date().timeIntervalSince(lastAlert) < repeatInterval { return }
        lastAlert = Date()
        Notifier.post(
            id: "lowDisk",
            title: "Your disk is almost full",
            body: "Only \(disk.availableForImportantUsage.formattedBytes) left. Open Mop to free up space.",
            section: .cleanup
        )
    }
}
