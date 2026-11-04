import MopCore
import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            Tab("General", systemImage: "gearshape") { GeneralSettings() }
            Tab("Cleaning", systemImage: "sparkles") { CleaningSettings() }
            Tab("Notifications", systemImage: "bell.badge") { NotificationSettings() }
            Tab("About", systemImage: "info.circle") { AboutSettings() }
        }
        .frame(width: 520, height: 400)
    }
}

private struct GeneralSettings: View {
    @Environment(AppState.self) private var state
    @AppStorage(Prefs.Key.openWindowAtLaunch) private var openWindowAtLaunch = true
    @AppStorage(Prefs.Key.showFreeSpaceInMenuBar) private var showFreeSpace = false
    @ViewState private var launchAtLogin = LaunchAtLogin.isEnabled
    @ViewState private var loginError: String?

    var body: some View {
        Form {
            Section {
                Toggle("Launch Mop at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        do {
                            try LaunchAtLogin.setEnabled(newValue)
                            loginError = nil
                        } catch {
                            loginError = error.localizedDescription
                            launchAtLogin = LaunchAtLogin.isEnabled
                        }
                    }
                if let loginError {
                    Text(loginError).font(.caption).foregroundStyle(.red)
                }
                Toggle("Open the Mop window when it starts", isOn: $openWindowAtLaunch)
                Toggle("Show free space next to the menu bar icon", isOn: $showFreeSpace)
            }
            Section("Permissions") {
                LabeledContent("Full Disk Access") {
                    HStack {
                        Text(state.hasFullDiskAccess ? "Granted" : "Not granted")
                            .foregroundStyle(state.hasFullDiskAccess ? .green : .orange)
                        Button("Open Settings") { FullDiskAccess.openSettings() }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}

private struct CleaningSettings: View {
    @AppStorage(Prefs.Key.autoCleanEnabled) private var autoCleanEnabled = false
    @AppStorage(Prefs.Key.autoCleanIntervalDays) private var intervalDays = 7
    @AppStorage(Prefs.Key.watchRemovedApps) private var watchRemovedApps = true
    @ViewState private var categories: Set<String> = Set(UserDefaults.standard.stringArray(forKey: Prefs.Key.autoCleanCategories) ?? [])

    private let safeCategories = CleanupCatalog.all().filter(\.isSafeForAutoClean)

    var body: some View {
        Form {
            Section {
                ForEach(safeCategories) { category in
                    Toggle(isOn: binding(category.id)) {
                        Label(category.name, systemImage: category.symbol)
                    }
                }
            } header: {
                Text("Quick Clean & auto-clean categories")
            } footer: {
                Text("Used by Quick Clean in the menu bar and by scheduled cleaning. Items are moved to the Trash.")
            }
            Section("Scheduled cleaning") {
                Toggle("Clean automatically", isOn: $autoCleanEnabled)
                Picker("Every", selection: $intervalDays) {
                    Text("Day").tag(1); Text("Week").tag(7); Text("2 weeks").tag(14); Text("Month").tag(30)
                }
                .disabled(!autoCleanEnabled)
                if let last = UserDefaults.standard.object(forKey: Prefs.Key.lastAutoClean) as? Date {
                    LabeledContent("Last run", value: last.relativeDescription)
                }
            }
            Section {
                Toggle("Detect apps deleted outside Mop", isOn: $watchRemovedApps)
            } footer: {
                Text("When you drag an app to the Trash in Finder, Mop offers to remove the files it left behind.")
            }
        }
        .formStyle(.grouped)
    }

    private func binding(_ id: String) -> Binding<Bool> {
        Binding(
            get: { categories.contains(id) },
            set: {
                if $0 { categories.insert(id) } else { categories.remove(id) }
                UserDefaults.standard.set(Array(categories).sorted(), forKey: Prefs.Key.autoCleanCategories)
            }
        )
    }
}

private struct NotificationSettings: View {
    @AppStorage(Prefs.Key.lowDiskAlertsEnabled) private var lowDiskEnabled = true
    @AppStorage(Prefs.Key.lowDiskThresholdGB) private var thresholdGB = 20

    var body: some View {
        Form {
            Section {
                Toggle("Alert me when disk space is low", isOn: $lowDiskEnabled)
                Picker("When less than", selection: $thresholdGB) {
                    ForEach([5, 10, 20, 30, 50, 100], id: \.self) { Text("\($0) GB available").tag($0) }
                }
                .disabled(!lowDiskEnabled)
            } footer: {
                Text(Notifier.isAvailable ? "Mop checks every minute and alerts at most every 6 hours."
                    : "Notifications only work when Mop runs as an app bundle (scripts/build-app.sh).")
            }
        }
        .formStyle(.grouped)
    }
}

private struct AboutSettings: View {
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "bubbles.and.sparkles")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
            Text("Mop").font(.title.bold())
            Text("Version \(version)").foregroundStyle(.secondary)
            Text("Uninstall apps, clean junk and keep an eye on your disk.")
            Link("github.com/luanpanno/mop", destination: URL(string: "https://github.com/luanpanno/mop")!)
            Text("MIT License").font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
