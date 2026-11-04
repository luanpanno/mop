import AppKit
import MopCore
import SwiftUI

struct LargeFilesView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case large = "Large & Old", duplicates = "Duplicates"
        var id: String { rawValue }
    }

    @ViewState private var mode: Mode = .large

    var body: some View {
        Group {
            switch mode {
            case .large: LargeOldFilesPane()
            case .duplicates: DuplicatesPane()
            }
        }
        .navigationTitle("Large Files")
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("Mode", selection: $mode) {
                    ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
            }
        }
    }
}

/// Folder chooser shared by the file finders.
struct FolderPicker: View {
    @Binding var folder: URL

    var body: some View {
        Button {
            let panel = NSOpenPanel()
            panel.canChooseDirectories = true
            panel.canChooseFiles = false
            panel.directoryURL = folder
            if panel.runModal() == .OK, let url = panel.url { folder = url }
        } label: {
            Label(folder.path.replacingOccurrences(of: NSHomeDirectory(), with: "~"), systemImage: "folder")
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: 260, alignment: .leading)
        }
    }
}

private struct LargeOldFilesPane: View {
    @Environment(AppState.self) private var state
    @ViewState private var folder = FileManager.default.homeDirectoryForCurrentUser
    @ViewState private var minSizeMB = 100
    @ViewState private var unusedDays = 0
    @ViewState private var results: [FileItem] = []
    @ViewState private var selection: Set<FileItem.ID> = []
    @ViewState private var scanTask: Task<[FileItem], Never>?
    @ViewState private var hasScanned = false
    @ViewState private var confirming = false
    @ViewState private var report: RemovalReport?

    private var selectedItems: [FileItem] { results.filter { selection.contains($0.id) } }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                FolderPicker(folder: $folder)
                Picker("Larger than", selection: $minSizeMB) {
                    Text("50 MB").tag(50); Text("100 MB").tag(100); Text("500 MB").tag(500); Text("1 GB").tag(1000)
                }
                .fixedSize()
                Picker("Not opened in", selection: $unusedDays) {
                    Text("Any time").tag(0); Text("1 month").tag(30); Text("3 months").tag(90)
                    Text("6 months").tag(180); Text("1 year").tag(365)
                }
                .fixedSize()
                Spacer()
                if scanTask != nil {
                    ProgressView().controlSize(.small)
                    Button("Stop") { scanTask?.cancel() }
                } else {
                    Button("Scan") { Task { await scan() } }.buttonStyle(.borderedProminent)
                }
            }
            .padding(12)
            Divider()

            Table(results, selection: $selection) {
                TableColumn("Name") { item in
                    HStack { FileIcon(url: item.url, size: 16); Text(item.name).lineLimit(1) }
                }
                TableColumn("Size") { item in
                    Text(item.size.formattedBytes).monospacedDigit()
                }
                .width(min: 70, ideal: 90, max: 110)
                TableColumn("Last opened") { item in
                    Text(item.lastUsed?.formatted(date: .abbreviated, time: .omitted) ?? "Never")
                        .foregroundStyle(.secondary)
                }
                .width(min: 90, ideal: 110, max: 140)
                TableColumn("Location") { item in
                    Text(item.url.deletingLastPathComponent().path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                        .foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                }
            }
            .contextMenu(forSelectionType: FileItem.ID.self) { ids in
                Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting(Array(ids)) }
                Button("Move to Trash…") { selection = ids; confirming = true }
            } primaryAction: { ids in
                NSWorkspace.shared.activateFileViewerSelecting(Array(ids))
            }
            .overlay {
                if results.isEmpty && hasScanned && scanTask == nil {
                    ContentUnavailableView("No large files found", systemImage: "checkmark.circle",
                                           description: Text("Try a smaller size or another folder."))
                } else if !hasScanned {
                    ContentUnavailableView("Find large and forgotten files", systemImage: "doc.viewfinder",
                                           description: Text("Choose a folder and press Scan."))
                }
            }

            if let report {
                RemovalReportBanner(report: report) { self.report = nil }
            }
            ActionBar {
                Text("\(results.count) files · \(selection.count) selected (\(selectedItems.totalSize.formattedBytes))")
                    .foregroundStyle(.secondary).monospacedDigit()
                Spacer()
                Button("Move to Trash…", role: .destructive) { confirming = true }
                    .disabled(selection.isEmpty)
            }
        }
        .confirmationDialog("Move \(selection.count) files (\(selectedItems.totalSize.formattedBytes)) to the Trash?", isPresented: $confirming) {
            Button("Move to Trash", role: .destructive) {
                Task {
                    let items = selectedItems
                    report = await state.trash(items)
                    let removed = Set(report?.removed.map(\.url) ?? [])
                    results.removeAll { removed.contains($0.url) }
                    selection.subtract(removed)
                }
            }
        }
    }

    private func scan() async {
        let finder = LargeFileFinder(
            minimumSize: Int64(minSizeMB) * 1_000_000,
            unusedSince: unusedDays > 0 ? Calendar.current.date(byAdding: .day, value: -unusedDays, to: Date()) : nil
        )
        let root = folder
        let task = Task.detached(priority: .userInitiated) { finder.scan(root) }
        scanTask = task
        results = []
        selection = []
        results = await task.value
        hasScanned = true
        scanTask = nil
    }
}

private struct DuplicatesPane: View {
    @Environment(AppState.self) private var state
    @ViewState private var folder = FileManager.default.homeDirectoryForCurrentUser
    @ViewState private var minSizeMB = 1
    @ViewState private var groups: [[FileItem]] = []
    @ViewState private var selected: Set<URL> = []
    @ViewState private var scanTask: Task<[[FileItem]], Never>?
    @ViewState private var hasScanned = false
    @ViewState private var confirming = false
    @ViewState private var report: RemovalReport?

    private var selectedItems: [FileItem] { groups.flatMap { $0 }.filter { selected.contains($0.url) } }
    /// Never allow trashing every copy of a file.
    private var removesAllCopies: Bool { groups.contains { group in group.allSatisfy { selected.contains($0.url) } } }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                FolderPicker(folder: $folder)
                Picker("Larger than", selection: $minSizeMB) {
                    Text("100 KB").tag(0); Text("1 MB").tag(1); Text("10 MB").tag(10); Text("100 MB").tag(100)
                }
                .fixedSize()
                Spacer()
                if scanTask != nil {
                    ProgressView().controlSize(.small)
                    Button("Stop") { scanTask?.cancel() }
                } else {
                    Button("Scan") { Task { await scan() } }.buttonStyle(.borderedProminent)
                }
            }
            .padding(12)
            Divider()

            List {
                ForEach(groups, id: \.first!.url) { group in
                    Section {
                        ForEach(group) { item in
                            Toggle(isOn: binding(item.url)) {
                                HStack {
                                    FileIcon(url: item.url, size: 16)
                                    Text(item.url.path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                                        .lineLimit(1).truncationMode(.middle)
                                    Spacer()
                                    if let modified = item.modified {
                                        Text(modified.formatted(date: .abbreviated, time: .omitted)).foregroundStyle(.secondary)
                                    }
                                    RevealButton(url: item.url)
                                }
                            }
                        }
                    } header: {
                        Text("\(group.first!.name) — \(group.count) copies · \(DuplicateFinder.wasted(group).formattedBytes) wasted")
                    }
                }
            }
            .overlay {
                if groups.isEmpty && hasScanned && scanTask == nil {
                    ContentUnavailableView("No duplicates found", systemImage: "checkmark.circle")
                } else if !hasScanned {
                    ContentUnavailableView("Find duplicate files", systemImage: "doc.on.doc",
                                           description: Text("Mop compares file contents, not just names. The oldest copy is kept by default."))
                }
            }

            if let report {
                RemovalReportBanner(report: report) { self.report = nil }
            }
            ActionBar {
                Text("\(groups.count) groups · \(selectedItems.totalSize.formattedBytes) selected").foregroundStyle(.secondary).monospacedDigit()
                if removesAllCopies {
                    Label("Keep at least one copy of each file", systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
                }
                Spacer()
                Button("Move to Trash…", role: .destructive) { confirming = true }
                    .disabled(selectedItems.isEmpty || removesAllCopies)
            }
        }
        .confirmationDialog("Move \(selectedItems.count) duplicates (\(selectedItems.totalSize.formattedBytes)) to the Trash?", isPresented: $confirming) {
            Button("Move to Trash", role: .destructive) {
                Task {
                    report = await state.trash(selectedItems)
                    let removed = Set(report?.removed.map(\.url) ?? [])
                    groups = groups.map { $0.filter { !removed.contains($0.url) } }.filter { $0.count > 1 }
                    selected.subtract(removed)
                }
            }
        }
    }

    private func binding(_ url: URL) -> Binding<Bool> {
        Binding(get: { selected.contains(url) }, set: { if $0 { selected.insert(url) } else { selected.remove(url) } })
    }

    private func scan() async {
        let finder = DuplicateFinder(minimumSize: minSizeMB == 0 ? 100_000 : Int64(minSizeMB) * 1_000_000)
        let root = folder
        let task = Task.detached(priority: .userInitiated) { finder.scan(root) }
        scanTask = task
        groups = []
        groups = await task.value
        // Preselect every copy except the oldest one.
        selected = Set(groups.flatMap { $0.dropFirst().map(\.url) })
        hasScanned = true
        scanTask = nil
    }
}
