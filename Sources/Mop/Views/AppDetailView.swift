import AppKit
import MopCore
import SwiftUI

struct AppDetailView: View {
    @Environment(AppState.self) private var state
    let app: InstalledApp

    @ViewState private var leftovers: [Leftover] = []
    @ViewState private var isLoading = true
    @ViewState private var includeApp = true
    @ViewState private var selected: Set<URL> = []
    @ViewState private var confirming = false
    @ViewState private var runningAlert = false
    @ViewState private var isRemoving = false
    @ViewState private var report: RemovalReport?

    private var selectedLeftovers: [Leftover] { leftovers.filter { selected.contains($0.url) } }
    private var selectedSize: Int64 {
        selectedLeftovers.reduce(includeApp ? app.size : 0) { $0 + $1.size }
    }
    private var selectedCount: Int { selectedLeftovers.count + (includeApp ? 1 : 0) }
    private var runningInstances: [NSRunningApplication] {
        guard let id = app.bundleID else { return [] }
        return NSRunningApplication.runningApplications(withBundleIdentifier: id)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            List {
                Section("Application") {
                    Toggle(isOn: $includeApp) {
                        HStack {
                            FileIcon(url: app.url)
                            Text(app.url.path).lineLimit(1).truncationMode(.middle)
                            Spacer()
                            Text(app.size.formattedBytes).monospacedDigit().foregroundStyle(.secondary)
                            RevealButton(url: app.url)
                        }
                    }
                }
                Section {
                    if isLoading {
                        HStack { ProgressView().controlSize(.small); Text("Looking for leftovers…") }
                    } else if leftovers.isEmpty {
                        Text("No leftovers found.").foregroundStyle(.secondary)
                    } else {
                        ForEach(leftovers) { leftover in
                            LeftoverRow(leftover: leftover, isOn: binding(leftover.url))
                        }
                    }
                } header: {
                    HStack {
                        Text("Related files")
                        Spacer()
                        if !leftovers.isEmpty {
                            Text(leftovers.reduce(0) { $0 + $1.size }.formattedBytes)
                        }
                    }
                } footer: {
                    if leftovers.contains(where: { $0.confidence == .possible }) {
                        Text("“Possible match” items only share the app's name. Check them before removing.")
                    }
                }
            }
            if let report {
                RemovalReportBanner(report: report) { self.report = nil }
            }
            ActionBar {
                Text("\(selectedCount) selected · \(selectedSize.formattedBytes)")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                Spacer()
                if isRemoving { ProgressView().controlSize(.small) }
                Button(includeApp ? "Uninstall…" : "Remove Leftovers…", role: .destructive) {
                    if includeApp && !runningInstances.isEmpty {
                        runningAlert = true
                    } else {
                        confirming = true
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .disabled(selectedCount == 0 || isRemoving)
            }
        }
        .task { await load() }
        .confirmationDialog(
            "Move \(selectedCount) items (\(selectedSize.formattedBytes)) to the Trash?",
            isPresented: $confirming
        ) {
            Button("Move to Trash", role: .destructive) { Task { await remove() } }
        } message: {
            Text(includeApp ? "\(app.name) and the selected files will be moved to the Trash. You can put them back from there." :
                "The selected files will be moved to the Trash.")
        }
        .alert("\(app.name) is running", isPresented: $runningAlert) {
            Button("Quit and Uninstall", role: .destructive) { Task { await quitAndRemove() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Mop needs to quit \(app.name) before removing it.")
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            FileIcon(url: app.url, size: 56)
            VStack(alignment: .leading, spacing: 3) {
                Text(app.name).font(.title2.bold())
                Text([app.version.map { "Version \($0)" }, app.bundleID].compactMap { $0 }.joined(separator: " · "))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                if let lastUsed = app.lastUsed {
                    Text("Last opened \(lastUsed.relativeDescription)").font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(18)
    }

    private func binding(_ url: URL) -> Binding<Bool> {
        Binding(get: { selected.contains(url) }, set: { if $0 { selected.insert(url) } else { selected.remove(url) } })
    }

    private func load() async {
        isLoading = true
        leftovers = await state.leftovers(for: app)
        selected = Set(leftovers.filter { $0.confidence == .exact }.map(\.url))
        isLoading = false
    }

    private func quitAndRemove() async {
        for instance in runningInstances { instance.terminate() }
        for _ in 0..<40 where !runningInstances.isEmpty {
            try? await Task.sleep(for: .milliseconds(250))
        }
        if !runningInstances.isEmpty {
            for instance in runningInstances { instance.forceTerminate() }
            try? await Task.sleep(for: .milliseconds(500))
        }
        await remove()
    }

    private func remove() async {
        isRemoving = true
        defer { isRemoving = false }
        report = await state.uninstall(app, includeApp: includeApp, leftovers: selectedLeftovers)
        if !includeApp || !(report?.removed.contains { $0.url == app.url } ?? false) {
            await load()
        }
    }
}

struct LeftoverRow: View {
    let leftover: Leftover
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack {
                FileIcon(url: leftover.url)
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text(leftover.url.lastPathComponent).lineLimit(1)
                        if leftover.confidence == .possible {
                            Text("Possible match")
                                .font(.caption2.weight(.medium))
                                .padding(.horizontal, 5).padding(.vertical, 1)
                                .background(.orange.opacity(0.2), in: .capsule)
                        }
                    }
                    Text(leftover.url.deletingLastPathComponent().path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                        .font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                }
                Spacer()
                Text(leftover.size.formattedBytes).monospacedDigit().foregroundStyle(.secondary)
                RevealButton(url: leftover.url)
            }
        }
    }
}
