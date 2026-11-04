import MopCore
import SwiftUI

/// Shown on a left click on the menu bar icon.
struct MenuBarPopoverView: View {
    @Environment(AppState.self) private var state
    @Environment(AppRouter.self) private var router

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Mop", systemImage: "bubbles.and.sparkles")
                    .font(.headline)
                Spacer()
                Button {
                    router.openSettings()
                } label: {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.borderless)
                .help("Settings")
            }

            if let disk = state.disk {
                HStack(spacing: 16) {
                    DiskUsageRing(disk: disk, lineWidth: 9)
                        .frame(width: 88, height: 88)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(disk.availableForImportantUsage.formattedBytes)
                            .font(.title2.weight(.semibold))
                        Text("available of \(disk.total.formattedBytes)")
                            .foregroundStyle(.secondary)
                        if disk.purgeable > 0 {
                            Text("incl. \(disk.purgeable.formattedBytes) purgeable")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            GroupBox {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Can be freed")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(state.reclaimable.formattedBytes)
                            .font(.title3.weight(.semibold))
                        if state.isScanningCleanup {
                            Text("Scanning…").font(.caption).foregroundStyle(.secondary)
                        } else if let date = state.lastCleanupScan {
                            Text("Scanned \(date, format: .relative(presentation: .named))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Button("Review") { router.openMain(.cleanup) }
                }
                .padding(4)
            }

            HStack {
                Button {
                    router.quickClean()
                } label: {
                    Label("Quick Clean", systemImage: "sparkles")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .disabled(state.isScanningCleanup)

                Button {
                    router.openMain()
                } label: {
                    Text("Open Mop").frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
            }
            .controlSize(.large)
        }
        .padding(16)
        .frame(width: 320)
    }
}
