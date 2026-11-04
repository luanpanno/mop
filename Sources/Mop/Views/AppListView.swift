import AppKit
import MopCore
import SwiftUI

struct AppListView: View {
    enum Sort: String, CaseIterable, Identifiable {
        case size = "Size", name = "Name", lastUsed = "Last Opened"
        var id: String { rawValue }
    }

    @Environment(AppState.self) private var state
    @ViewState private var search = ""
    @ViewState private var sort: Sort = .size
    @ViewState private var selection: InstalledApp.ID?
    @ViewState private var dropTarget = false

    private var filtered: [InstalledApp] {
        let apps = search.isEmpty ? state.apps : state.apps.filter {
            $0.name.localizedCaseInsensitiveContains(search) || ($0.bundleID ?? "").localizedCaseInsensitiveContains(search)
        }
        switch sort {
        case .size: return apps.sorted { $0.size > $1.size }
        case .name: return apps.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        case .lastUsed: return apps.sorted { ($0.lastUsed ?? .distantPast) < ($1.lastUsed ?? .distantPast) }
        }
    }

    var body: some View {
        HSplitView {
            List(filtered, selection: $selection) { app in
                AppRow(app: app).tag(app.id)
            }
            .overlay {
                if state.apps.isEmpty && state.isScanningApps {
                    ProgressView("Scanning applications…")
                } else if filtered.isEmpty && !search.isEmpty {
                    ContentUnavailableView.search(text: search)
                }
            }
            .overlay {
                if dropTarget {
                    RoundedRectangle(cornerRadius: 12).strokeBorder(Color.accentColor, lineWidth: 3).padding(4)
                }
            }
            .dropDestination(for: URL.self) { urls, _ in
                handleDrop(urls)
            } isTargeted: { dropTarget = $0 }
            .frame(minWidth: 280, idealWidth: 330, maxWidth: 420)

            Group {
                if let id = selection, let app = state.apps.first(where: { $0.id == id }) {
                    AppDetailView(app: app).id(app.id)
                } else {
                    ContentUnavailableView(
                        "Select an app",
                        systemImage: "xmark.app",
                        description: Text("Pick an app to see its leftovers, or drag an app here from Finder.")
                    )
                }
            }
            .frame(minWidth: 420, maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("Uninstaller")
        .navigationSubtitle(state.apps.isEmpty ? "" : "\(state.apps.count) apps")
        .searchable(text: $search, placement: .toolbar, prompt: "Search apps")
        .toolbar {
            ToolbarItem {
                Picker("Sort", selection: $sort) {
                    ForEach(Sort.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.menu)
            }
            ToolbarItem {
                Button {
                    Task { await state.scanApps() }
                } label: {
                    Label("Rescan", systemImage: "arrow.clockwise")
                }
                .disabled(state.isScanningApps)
            }
        }
        .task {
            if state.apps.isEmpty { await state.scanApps() }
        }
    }

    private func handleDrop(_ urls: [URL]) -> Bool {
        guard let url = urls.first(where: { $0.pathExtension == "app" }) else { return false }
        if let existing = state.apps.first(where: { $0.url.standardizedFileURL == url.standardizedFileURL }) {
            selection = existing.id
            return true
        }
        guard var app = InstalledApp.metadata(at: url) else { return false }
        if app.isAppleApp { return false }
        app.size = DirectorySizer.size(of: url)
        state.apps.append(app)
        selection = app.id
        return true
    }
}

private struct AppRow: View {
    let app: InstalledApp

    var body: some View {
        HStack(spacing: 10) {
            FileIcon(url: app.url, size: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(app.name).lineLimit(1)
                Group {
                    if let lastUsed = app.lastUsed {
                        Text("Opened \(lastUsed.relativeDescription)")
                    } else {
                        Text("Never opened")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Text(app.size.formattedBytes)
                .font(.callout)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
