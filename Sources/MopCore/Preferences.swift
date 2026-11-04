import Foundation

/// UserDefaults keys and defaults shared by the app and its monitors.
public enum Prefs {
    public enum Key {
        public static let openWindowAtLaunch = "openWindowAtLaunch"
        public static let showFreeSpaceInMenuBar = "showFreeSpaceInMenuBar"
        public static let lowDiskAlertsEnabled = "lowDiskAlertsEnabled"
        public static let lowDiskThresholdGB = "lowDiskThresholdGB"
        public static let autoCleanEnabled = "autoCleanEnabled"
        public static let autoCleanIntervalDays = "autoCleanIntervalDays"
        public static let autoCleanCategories = "autoCleanCategories"
        public static let watchRemovedApps = "watchRemovedApps"
        public static let fullDiskAccessOnboardingDone = "fullDiskAccessOnboardingDone"
        public static let lastReclaimableBytes = "lastReclaimableBytes"
        public static let lastCleanupScan = "lastCleanupScan"
        public static let lastAutoClean = "lastAutoClean"
    }

    public static func registerDefaults(_ defaults: UserDefaults = .standard) {
        defaults.register(defaults: [
            Key.openWindowAtLaunch: true,
            Key.showFreeSpaceInMenuBar: false,
            Key.lowDiskAlertsEnabled: true,
            Key.lowDiskThresholdGB: 20,
            Key.autoCleanEnabled: false,
            Key.autoCleanIntervalDays: 7,
            Key.autoCleanCategories: ["userCaches", "logs", "xcodeDerivedData"],
            Key.watchRemovedApps: true,
            Key.fullDiskAccessOnboardingDone: false,
        ])
    }
}
