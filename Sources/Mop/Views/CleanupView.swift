import MopCore
import SwiftUI

struct CleanupView: View {
    @Environment(AppState.self) private var state
    @ViewState private var selected: Set<String> = []
    @ViewState private var didInitSelection = false
    @ViewState private var confirming = false
    @ViewState private var isCleaning = false
    @ViewState private var report: RemovalReport?

    private var selectedResults: [CleanupResult] {
        state.cleanupResults.filter { selected.contains($0.id) && $0.total > 0 }
    }
    private var selectedSize: Int64 { selectedResults.reduce(0) { $0 + $1.total } }
    private var includesPermanent: Bool { selectedResults.contains { $0.category.removal == .permanent } }

    var body: some View {
        VStack(spacing: 0) {
            List {
                ForEach(state.cleanupResults) { result in
                    CategoryRow(result: result, isOn: binding(result.id))
                }
            }
            .overlay {
                if state.cleanupResults.isEmpty && state.isScanningCleanup {
                    ProgressView("Scanning for junk…")
                }
            }
            if let report {
                RemovalReportBanner(report: report) { self.report = nil }
            }
            ActionBar {
                Text("\(selectedSize.formattedBytes) selected").monospacedDigit().foregroundStyle(.secondary)
                Spacer()
                if isCleaning || state.isScanningCleanup { ProgressView().controlSize(.small) }
                Button("Clean Up…") { confirming = true }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedSize == 0 || isCleaning)
            }
        }
        .navigationTitle("Cleanup")
        .navigationSubtitle("\(state.reclaimable.formattedBytes) can be freed")
        .toolbar {
            ToolbarItem {
                Button {
                    Task { await state.scanCleanup() }
                } label: {
                    Label("Rescan", systemImage: "arrow.clockwise")
                }
                .disabled(state.isScanningCleanup)
            }
        }
        .task {
            if state.cleanupResults.isEmpty { await state.scanCleanup() }
        }
        .onChange(of: state.cleanupResults.count, initial: true) {
            guard !didInitSelection, !state.cleanupResults.isEmpty else { return }
            selected = Set(state.cleanupResults.filter { $0.category.isSafeForAutoClean }.map(\.id))
            didInitSelection = true
        }
        .confirmationDialog("Clean \(selectedSize.formattedBytes)?", isPresented: $confirming) {
            Button(includesPermanent ? "Clean and Empty Trash" : "Move to Trash", role: .destructive) {
                Task {
                    isCleaning = true
                    report = await state.clean(selectedResults)
                    isCleaning = false
                }
            }
        } message: {
            Text(selectedResults.map { "\($0.category.name): \($0.total.formattedBytes)" }.joined(separator: "\n")
                + (includesPermanent ? "\n\nItems already in the Trash will be deleted permanently." : "\n\nItems are moved to the Trash."))
        }
    }

    private func binding(_ id: String) -> Binding<Bool> {
        Binding(get: { selected.contains(id) }, set: { if $0 { selected.insert(id) } else { selected.remove(id) } })
    }
}

private struct CategoryRow: View {
    let result: CleanupResult
    @Binding var isOn: Bool
    @ViewState private var expanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            ForEach(result.items.prefix(50)) { item in
                HStack {
                    FileIcon(url: item.url, size: 16)
                    Text(item.name).lineLimit(1).truncationMode(.middle)
                    Spacer()
                    Text(item.size.formattedBytes).monospacedDigit().foregroundStyle(.secondary)
                    RevealButton(url: item.url)
                }
                .font(.callout)
            }
            if result.items.count > 50 {
                Text("and \(result.items.count - 50) more…").font(.caption).foregroundStyle(.secondary)
            }
        } label: {
            HStack(spacing: 12) {
                Toggle("", isOn: $isOn).labelsHidden().disabled(result.total == 0)
                Image(systemName: result.category.symbol)
                    .font(.title3)
                    .foregroundStyle(result.category.removal == .permanent ? .red : .accentColor)
                    .frame(width: 26)
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.category.name).font(.headline)
                    Text(result.category.detail).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(result.total.formattedBytes)
                    .monospacedDigit()
                    .foregroundStyle(result.total == 0 ? .tertiary : .primary)
            }
            .padding(.vertical, 4)
        }
    }
}
