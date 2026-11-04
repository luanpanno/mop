import AppKit
import MopCore
import UserNotifications

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    let state = AppState()
    let router = AppRouter()

    private var windows: WindowManager!
    private var statusItem: StatusItemController!
    private let lowDisk = LowDiskMonitor()
    private var autoClean: AutoCleanScheduler!
    private let removalWatcher = AppRemovalWatcher()
    private var diskTimer: Timer?
    private var launchedAtLogin = false
    private var lastSettingsSignature = ""

    func applicationWillFinishLaunching(_ notification: Notification) {
        Prefs.registerDefaults()
        // Login items are launched with a special "open application" Apple event.
        if let event = NSAppleEventManager.shared().currentAppleEvent,
           event.eventID == kAEOpenApplication,
           event.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem {
            launchedAtLogin = true
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = MainMenu.build()

        windows = WindowManager(state: state, router: router)
        statusItem = StatusItemController(state: state, router: router)
        router.openMainHandler = { [weak self] section in self?.windows.showMain(section: section) }
        router.openSettingsHandler = { [weak self] in self?.windows.showMain(section: .settings) }
        router.closePopoverHandler = { [weak self] in self?.statusItem.closePopover() }
        router.quickCleanHandler = { [weak self] in self?.confirmQuickClean() }

        if Notifier.isAvailable {
            UNUserNotificationCenter.current().delegate = self
        }

        state.refreshDisk()
        lowDisk.evaluate(state.disk)
        diskTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        Task { await state.scanCleanup() }

        autoClean = AutoCleanScheduler(state: state)
        removalWatcher.onAppRemoved = { [weak self] app in self?.handleRemovedApp(app) }
        applySettings()
        NotificationCenter.default.addObserver(
            self, selector: #selector(defaultsChanged), name: UserDefaults.didChangeNotification, object: nil
        )
        Task {
            try? await Task.sleep(for: .seconds(90))
            await autoClean.runIfDue()
        }

        // Mop launches as a regular app (with a Dock icon). Only drop to menu-bar-only mode when no
        // window is shown: switching to .accessory and back right away would leave the window unfocused.
        let defaults = UserDefaults.standard
        if !state.hasFullDiskAccess && !defaults.bool(forKey: Prefs.Key.fullDiskAccessOnboardingDone) {
            state.showOnboarding = true
            windows.showMain()
        } else if !launchedAtLogin && defaults.bool(forKey: Prefs.Key.openWindowAtLaunch) {
            windows.showMain()
        } else {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    /// Opening Mop again from Finder, Spotlight, Launchpad or the Dock while it's running in the menu bar.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        windows.showMain()
        return false
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func tick() {
        state.refreshDisk()
        lowDisk.evaluate(state.disk)
    }

    // MARK: Settings-driven monitors

    @objc private func defaultsChanged() {
        applySettings()
    }

    private func applySettings() {
        let d = UserDefaults.standard
        let signature = [
            d.bool(forKey: Prefs.Key.autoCleanEnabled).description,
            d.integer(forKey: Prefs.Key.autoCleanIntervalDays).description,
            d.bool(forKey: Prefs.Key.watchRemovedApps).description,
            d.bool(forKey: Prefs.Key.lowDiskAlertsEnabled).description,
            d.integer(forKey: Prefs.Key.lowDiskThresholdGB).description,
        ].joined(separator: "|")
        guard signature != lastSettingsSignature else { return }
        lastSettingsSignature = signature

        autoClean.reconfigure()
        if d.bool(forKey: Prefs.Key.watchRemovedApps) {
            removalWatcher.start()
        } else {
            removalWatcher.stop()
        }
        if d.bool(forKey: Prefs.Key.lowDiskAlertsEnabled) || d.bool(forKey: Prefs.Key.autoCleanEnabled)
            || d.bool(forKey: Prefs.Key.watchRemovedApps) {
            Notifier.requestAuthorization()
        }
        lowDisk.evaluate(state.disk)
    }

    // MARK: Apps removed outside Mop

    private func handleRemovedApp(_ app: InstalledApp) {
        if state.recentlyUninstalled.remove(app.url) != nil { return }
        Task {
            let leftovers = await state.leftovers(bundleID: app.bundleID, name: app.name, teamID: app.teamID)
                .filter { $0.confidence == .exact }
            guard !leftovers.isEmpty else { return }
            let orphan = OrphanedApp(name: app.name, leftovers: leftovers)
            state.orphans.append(orphan)
            Notifier.post(
                id: "orphan-\(app.url.path)",
                title: "\(app.name) left files behind",
                body: "\(orphan.total.formattedBytes) of leftovers remain. Click to review them in Mop.",
                section: .uninstaller
            )
        }
    }

    // MARK: Quick Clean

    private func confirmQuickClean() {
        let ids = Set(UserDefaults.standard.stringArray(forKey: Prefs.Key.autoCleanCategories) ?? [])
        let results = state.cleanupResults.filter { ids.contains($0.id) && $0.category.isSafeForAutoClean && $0.total > 0 }
        let total = results.reduce(0) { $0 + $1.total }

        NSApp.activate()
        let alert = NSAlert()
        guard total > 0 else {
            alert.messageText = state.isScanningCleanup ? "Mop is still scanning" : "Nothing to clean"
            alert.informativeText = "The Quick Clean categories are empty. You can choose them in Settings → Cleaning."
            alert.runModal()
            return
        }
        alert.messageText = "Clean \(total.formattedBytes)?"
        alert.informativeText = results.map { "• \($0.category.name): \($0.total.formattedBytes)" }.joined(separator: "\n")
            + "\n\nItems are moved to the Trash."
        alert.addButton(withTitle: "Move to Trash")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        Task {
            let report = await state.clean(results)
            let done = NSAlert()
            done.messageText = "Moved \(report.bytesRemoved.formattedBytes) to the Trash"
            done.informativeText = report.failed.isEmpty
                ? "Empty the Trash to reclaim the space."
                : "\(report.failed.count) items couldn't be removed (they may be in use)."
            NSApp.activate()
            done.runModal()
        }
    }

    // MARK: Menu actions

    @objc func showSettings(_ sender: Any?) {
        windows.showMain(section: .settings)
    }

    @objc func showSection(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String else { return }
        windows.showMain(section: SidebarSection(rawValue: raw))
    }

    // MARK: Notifications

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse
    ) async {
        let raw = response.notification.request.content.userInfo[Notifier.sectionKey] as? String
        await MainActor.run {
            windows.showMain(section: raw.flatMap(SidebarSection.init(rawValue:)))
        }
    }
}
