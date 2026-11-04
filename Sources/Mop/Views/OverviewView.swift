import Charts
import MopCore
import SwiftUI

struct OverviewView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let disk = state.disk {
                    DiskSummaryCard(disk: disk)
                }
                ReclaimableCard()
                JunkChartCard()
                LocationsCard()
            }
            .padding(24)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Overview")
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
    }
}

private struct Card<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title).font(.headline)
            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: .rect(cornerRadius: 16))
    }
}

private struct DiskSummaryCard: View {
    let disk: DiskInfo

    var body: some View {
        Card(title: "Macintosh HD") {
            HStack(spacing: 32) {
                DiskUsageRing(disk: disk, lineWidth: 16)
                    .frame(width: 150, height: 150)
                Grid(alignment: .leading, horizontalSpacing: 28, verticalSpacing: 12) {
                    GridRow {
                        Stat(title: "Total", value: disk.total.formattedBytes, color: .secondary)
                        Stat(title: "Used", value: disk.used.formattedBytes, color: .accentColor)
                    }
                    GridRow {
                        Stat(title: "Available", value: disk.availableForImportantUsage.formattedBytes, color: .green)
                        Stat(title: "Purgeable", value: disk.purgeable.formattedBytes, color: .accentColor.opacity(0.4),
                             help: "Space macOS frees automatically when needed (snapshots, iCloud copies, caches).")
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }
}

private struct Stat: View {
    let title: String
    let value: String
    let color: Color
    var help: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label {
                Text(title).foregroundStyle(.secondary)
            } icon: {
                Circle().fill(color).frame(width: 8, height: 8)
            }
            .font(.callout)
            Text(value).font(.title2.weight(.semibold)).monospacedDigit()
        }
        .help(help ?? "")
    }
}

private struct ReclaimableCard: View {
    @Environment(AppState.self) private var state
    @Environment(AppRouter.self) private var router

    var body: some View {
        Card(title: "Space Mop can free") {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(state.reclaimable.formattedBytes)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())
                    if state.isScanningCleanup {
                        ProgressView().controlSize(.small)
                    } else if let date = state.lastCleanupScan {
                        Text("Last scanned \(date.relativeDescription)").foregroundStyle(.secondary).font(.caption)
                    }
                }
                Spacer()
                Button("Review & Clean") { router.openMain(.cleanup) }
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
            }
        }
    }
}

private struct JunkChartCard: View {
    @Environment(AppState.self) private var state

    var body: some View {
        let results = state.cleanupResults.filter { $0.total > 0 }
        if !results.isEmpty {
            Card(title: "Junk by category") {
                Chart(results) { result in
                    BarMark(
                        x: .value("Size (GB)", Double(result.total) / 1_000_000_000),
                        y: .value("Category", result.category.name)
                    )
                    .foregroundStyle(by: .value("Category", result.category.name))
                    .annotation(position: .trailing) {
                        Text(result.total.formattedBytes).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .chartLegend(.hidden)
                .chartXAxisLabel("GB")
                .frame(height: CGFloat(results.count) * 34 + 30)
            }
        }
    }
}

private struct LocationsCard: View {
    @Environment(AppState.self) private var state

    var body: some View {
        Card(title: "Space by folder") {
            if state.locationBreakdown.isEmpty {
                HStack {
                    Text("Measure your main folders to see where your space goes. This can take a minute.")
                        .foregroundStyle(.secondary)
                    Spacer()
                    if state.isAnalyzingLocations {
                        ProgressView().controlSize(.small)
                    } else {
                        Button("Analyze") { Task { await state.analyzeLocations() } }
                    }
                }
            } else {
                Chart(state.locationBreakdown) { item in
                    BarMark(
                        x: .value("Size (GB)", Double(item.size) / 1_000_000_000),
                        y: .value("Folder", item.url.path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                    )
                    .annotation(position: .trailing) {
                        Text(item.size.formattedBytes).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .chartXAxisLabel("GB")
                .frame(height: CGFloat(state.locationBreakdown.count) * 30 + 30)
                HStack {
                    Spacer()
                    Button("Analyze again") { Task { await state.analyzeLocations() } }
                        .disabled(state.isAnalyzingLocations)
                }
            }
        }
    }
}
