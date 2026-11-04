import AppKit
import MopCore
import SwiftUI

/// Finder icon for a file or folder.
struct FileIcon: View {
    let url: URL
    var size: CGFloat = 20

    var body: some View {
        Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
            .resizable()
            .interpolation(.high)
            .frame(width: size, height: size)
    }
}

struct RevealButton: View {
    let url: URL

    var body: some View {
        Button {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } label: {
            Image(systemName: "magnifyingglass")
        }
        .buttonStyle(.borderless)
        .help("Show in Finder")
    }
}

/// Shows the outcome of a removal at the bottom of a screen.
struct RemovalReportBanner: View {
    let report: RemovalReport
    var onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: report.failed.isEmpty ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(report.failed.isEmpty ? .green : .orange)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text("Removed \(report.removed.count) items (\(report.bytesRemoved.formattedBytes))")
                    .font(.headline)
                if report.failed.isEmpty {
                    Text("Items are in the Trash. Empty it to reclaim the space.")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("\(report.failed.count) couldn't be removed: " + report.failed.prefix(3).map { "\($0.item.name) (\($0.reason))" }.joined(separator: ", "))
                        .font(.caption).foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer()
            Button("Open Trash") {
                NSWorkspace.shared.open(FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".Trash"))
            }
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.borderless)
        }
        .padding(12)
        .glassEffect(.regular, in: .rect(cornerRadius: 14))
        .padding(12)
    }
}

/// Bottom action bar used by list screens.
struct ActionBar<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        HStack(spacing: 12) { content }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.bar)
    }
}

extension Date {
    var relativeDescription: String {
        formatted(.relative(presentation: .named))
    }
}

/// SwiftUI's `State` property wrapper.
///
/// Recent SDKs declare `@State` as a macro whose compiler plugin ships only with Xcode,
/// so plain `@State` fails to build with the Command Line Tools. This alias names the
/// underlying property wrapper type directly and builds with both toolchains.
typealias ViewState<Value> = SwiftUI.State<Value>
