import AppKit
import MopCore

/// Periodically cleans the categories chosen in Settings (only ones marked safe for auto-clean).
@MainActor
final class AutoCleanScheduler {
    private let state: AppState
    private var scheduler: NSBackgroundActivityScheduler?
    private var isRunning = false

    init(state: AppState) {
        self.state = state
    }

    private var defaults: UserDefaults { .standard }
    private var intervalDays: Int { max(1, defaults.integer(forKey: Prefs.Key.autoCleanIntervalDays)) }
    private var isEnabled: Bool { defaults.bool(forKey: Prefs.Key.autoCleanEnabled) }

    /// (Re)creates the background schedule from the current settings.
    func reconfigure() {
        scheduler?.invalidate()
        scheduler = nil
        guard isEnabled else { return }

        let activity = NSBackgroundActivityScheduler(identifier: "com.luanpanno.mop.autoclean")
        activity.repeats = true
        activity.interval = TimeInterval(intervalDays) * 86_400
        activity.tolerance = 3600
        activity.qualityOfService = .utility
        activity.schedule { [weak self] completion in
            Task { @MainActor in
                await self?.runIfDue()
                completion(.finished)
            }
        }
        scheduler = activity
    }

    /// Runs when the last auto-clean is older than the configured interval.
    func runIfDue() async {
        guard isEnabled, !isRunning else { return }
        if let last = defaults.object(forKey: Prefs.Key.lastAutoClean) as? Date,
           Date().timeIntervalSince(last) < TimeInterval(intervalDays) * 86_400 - 3600 {
            return
        }
        isRunning = true
        defer { isRunning = false }

        let ids = Set(defaults.stringArray(forKey: Prefs.Key.autoCleanCategories) ?? [])
        let categories = CleanupCatalog.all().filter { ids.contains($0.id) && $0.isSafeForAutoClean }
        guard !categories.isEmpty else { return }

        let results = await CleanupScanner.scan(categories)
        let report = await state.clean(results.filter { $0.total > 0 })
        defaults.set(Date(), forKey: Prefs.Key.lastAutoClean)

        if report.bytesRemoved > 0 {
            Notifier.post(
                id: "autoClean",
                title: "Mop cleaned \(report.bytesRemoved.formattedBytes)",
                body: "Caches and logs were moved to the Trash. Empty the Trash to reclaim the space."
            )
        }
    }
}
