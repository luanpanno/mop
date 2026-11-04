import MopCore
import SwiftUI

struct MainView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var state = state
        NavigationSplitView {
            List(selection: Binding(get: { state.section }, set: { if let s = $0 { state.section = s } })) {
                Section {
                    ForEach(SidebarSection.tools) { section in
                        Label(section.title, systemImage: section.symbol).tag(section)
                    }
                }
                Section {
                    Label(SidebarSection.settings.title, systemImage: SidebarSection.settings.symbol)
                        .tag(SidebarSection.settings)
                }
            }
            .navigationSplitViewColumnWidth(min: 190, ideal: 210)
            .safeAreaInset(edge: .bottom) { SidebarDiskFooter() }
        } detail: {
            VStack(spacing: 0) {
                ForEach(state.orphans) { orphan in
                    OrphanBanner(orphan: orphan)
                }
                Group {
                    switch state.section {
                    case .overview: OverviewView()
                    case .uninstaller: AppListView()
                    case .cleanup: CleanupView()
                    case .largeFiles: LargeFilesView()
                    case .settings: SettingsView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .sheet(isPresented: $state.showOnboarding) {
            FullDiskAccessView()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            state.refreshPermissions()
            state.refreshDisk()
        }
    }
}

private struct SidebarDiskFooter: View {
    @Environment(AppState.self) private var state

    var body: some View {
        if let disk = state.disk {
            VStack(alignment: .leading, spacing: 6) {
                ProgressView(value: disk.usedFraction)
                    .tint(disk.usedFraction > 0.9 ? .red : .accentColor)
                Text("\(disk.availableForImportantUsage.formattedBytes) available")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(14)
        }
    }
}

/// "X was removed but left Y behind" banner with a review sheet.
private struct OrphanBanner: View {
    @Environment(AppState.self) private var state
    let orphan: OrphanedApp
    @ViewState private var reviewing = false

    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.bubble.fill").foregroundStyle(.orange)
            Text("**\(orphan.name)** was deleted, but left \(orphan.total.formattedBytes) behind.")
            Spacer()
            Button("Review…") { reviewing = true }
            Button("Dismiss") { dismiss() }
        }
        .padding(10)
        .background(.orange.opacity(0.12))
        .sheet(isPresented: $reviewing) {
            OrphanReviewSheet(orphan: orphan) { dismiss() }
        }
    }

    private func dismiss() {
        state.orphans.removeAll { $0.id == orphan.id }
    }
}

private struct OrphanReviewSheet: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    let orphan: OrphanedApp
    var onDone: () -> Void
    @ViewState private var selected: Set<URL> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Leftovers of \(orphan.name)").font(.title2.bold())
            List(orphan.leftovers) { leftover in
                LeftoverRow(leftover: leftover, isOn: binding(leftover.url))
            }
            .frame(minHeight: 240)
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Move to Trash") {
                    Task {
                        let items = orphan.leftovers.filter { selected.contains($0.url) }.map { FileItem(url: $0.url, size: $0.size) }
                        _ = await state.trash(items)
                        onDone()
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(selected.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 560, height: 420)
        .onAppear { selected = Set(orphan.leftovers.map(\.url)) }
    }

    private func binding(_ url: URL) -> Binding<Bool> {
        Binding(get: { selected.contains(url) }, set: { if $0 { selected.insert(url) } else { selected.remove(url) } })
    }
}
