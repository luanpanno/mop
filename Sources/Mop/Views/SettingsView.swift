import AppKit
import MopCore
import SwiftUI

/// Settings, shown as a section of the main window (like System Settings).
struct SettingsView: View {
    var body: some View {
        Form {
            GeneralSection()
            CleaningSection()
            NotificationSection()
            PermissionsSection()
            AboutSection()
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .frame(maxWidth: 680)
        .frame(maxWidth: .infinity)
        .navigationTitle("Settings")
    }
}

// MARK: - Building blocks

/// Colored rounded-square icon, as used in System Settings rows.
private struct SettingsIcon: View {
    let symbol: String
    let color: Color

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 24, height: 24)
            .background(color.gradient, in: .rect(cornerRadius: 6))
    }
}

/// A settings row: icon, title and an optional description.
private struct RowLabel: View {
    let title: String
    var detail: String?
    let symbol: String
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            SettingsIcon(symbol: symbol, color: color)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                if let detail {
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Sections

private struct GeneralSection: View {
    @AppStorage(Prefs.Key.openWindowAtLaunch) private var openWindowAtLaunch = true
    @AppStorage(Prefs.Key.showFreeSpaceInMenuBar) private var showFreeSpace = false
    @ViewState private var launchAtLogin = LaunchAtLogin.isEnabled
    @ViewState private var loginError: String?

    var body: some View {
        Section("General") {
            Toggle(isOn: $launchAtLogin) {
                RowLabel(title: "Launch at login", detail: "Mop starts quietly in the menu bar.",
                         symbol: "power", color: .green)
            }
            .onChange(of: launchAtLogin) { _, newValue in
                guard newValue != LaunchAtLogin.isEnabled else { return }
                do {
                    try LaunchAtLogin.setEnabled(newValue)
                    loginError = nil
                } catch {
                    loginError = error.localizedDescription
                    launchAtLogin = LaunchAtLogin.isEnabled
                }
            }
            if let loginError {
                Label(loginError, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            Toggle(isOn: $openWindowAtLaunch) {
                RowLabel(title: "Open the window when Mop starts", symbol: "macwindow", color: .blue)
            }
            Toggle(isOn: $showFreeSpace) {
                RowLabel(title: "Show free space in the menu bar", detail: "Next to the Mop icon.",
                         symbol: "menubar.rectangle", color: .indigo)
            }
        }
    }
}

private struct CleaningSection: View {
    @AppStorage(Prefs.Key.autoCleanEnabled) private var autoCleanEnabled = false
    @AppStorage(Prefs.Key.autoCleanIntervalDays) private var intervalDays = 7
    @AppStorage(Prefs.Key.watchRemovedApps) private var watchRemovedApps = true
    @ViewState private var categories: Set<String> =
        Set(UserDefaults.standard.stringArray(forKey: Prefs.Key.autoCleanCategories) ?? [])

    private let safeCategories = CleanupCatalog.all().filter(\.isSafeForAutoClean)

    var body: some View {
        Section {
            ForEach(safeCategories) { category in
                Toggle(isOn: binding(category.id)) {
                    Label(category.name, systemImage: category.symbol)
                }
            }
        } header: {
            Text("Quick Clean")
        } footer: {
            Text("The categories cleaned by Quick Clean in the menu bar and by scheduled cleaning. Items are moved to the Trash.")
        }

        Section {
            Toggle(isOn: $autoCleanEnabled) {
                RowLabel(title: "Clean automatically", detail: lastRunDescription,
                         symbol: "clock.arrow.circlepath", color: .teal)
            }
            if autoCleanEnabled {
                Picker("Repeat", selection: $intervalDays) {
                    Text("Every day").tag(1)
                    Text("Every week").tag(7)
                    Text("Every 2 weeks").tag(14)
                    Text("Every month").tag(30)
                }
            }
            Toggle(isOn: $watchRemovedApps) {
                RowLabel(title: "Detect apps deleted outside Mop",
                         detail: "Offers to remove leftovers when you drag an app to the Trash in Finder.",
                         symbol: "app.badge.checkmark", color: .orange)
            }
        } header: {
            Text("Automation")
        }
    }

    private var lastRunDescription: String {
        guard let last = UserDefaults.standard.object(forKey: Prefs.Key.lastAutoClean) as? Date else {
            return "Cleans the Quick Clean categories on a schedule."
        }
        return "Last run \(last.relativeDescription)."
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

private struct NotificationSection: View {
    @AppStorage(Prefs.Key.lowDiskAlertsEnabled) private var lowDiskEnabled = true
    @AppStorage(Prefs.Key.lowDiskThresholdGB) private var thresholdGB = 20

    var body: some View {
        Section {
            Toggle(isOn: $lowDiskEnabled) {
                RowLabel(title: "Alert when disk space is low", symbol: "bell.badge.fill", color: .red)
            }
            if lowDiskEnabled {
                Picker("Alert below", selection: $thresholdGB) {
                    ForEach([5, 10, 20, 30, 50, 100], id: \.self) { Text("\($0) GB available").tag($0) }
                }
            }
        } header: {
            Text("Notifications")
        } footer: {
            if !Notifier.isAvailable {
                Text("Notifications only work when Mop runs as an app bundle (scripts/build-app.sh).")
            }
        }
    }
}

private struct PermissionsSection: View {
    @Environment(AppState.self) private var state

    var body: some View {
        Section {
            LabeledContent {
                if state.hasFullDiskAccess {
                    Label("Granted", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Button("Grant Access…") { FullDiskAccess.openSettings() }
                }
            } label: {
                RowLabel(
                    title: "Full Disk Access",
                    detail: state.hasFullDiskAccess
                        ? "Mop can scan every folder."
                        : "Needed to find leftovers in protected folders like app containers.",
                    symbol: "lock.shield.fill",
                    color: state.hasFullDiskAccess ? .green : .gray
                )
            }
        } header: {
            Text("Permissions")
        }
    }
}

private struct AboutSection: View {
    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "dev"
        let build = info?["CFBundleVersion"] as? String
        return build.map { "\(short) (\($0))" } ?? short
    }

    var body: some View {
        Section("About") {
            LabeledContent {
                Text(version).foregroundStyle(.secondary).textSelection(.enabled)
            } label: {
                RowLabel(title: "Mop", detail: "Uninstall apps, clean junk and keep an eye on your disk.",
                         symbol: "bubbles.and.sparkles.fill", color: .cyan)
            }
            LabeledContent("Removal log") {
                Button("Show in Finder") {
                    let log = RemovalLog.folder.appendingPathComponent("removals.log")
                    if FileManager.default.fileExists(atPath: log.path) {
                        NSWorkspace.shared.activateFileViewerSelecting([log])
                    } else {
                        NSWorkspace.shared.open(RemovalLog.folder.deletingLastPathComponent())
                    }
                }
            }
            LabeledContent("Source code") {
                Link("github.com/luanpanno/mop", destination: URL(string: "https://github.com/luanpanno/mop")!)
            }
            LabeledContent("License", value: "MIT")
        }
    }
}
