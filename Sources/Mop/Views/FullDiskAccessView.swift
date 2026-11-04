import MopCore
import SwiftUI

/// First-run explanation of Full Disk Access.
struct FullDiskAccessView: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: state.hasFullDiskAccess ? "checkmark.shield.fill" : "lock.shield")
                .font(.system(size: 54))
                .foregroundStyle(state.hasFullDiskAccess ? .green : .accentColor)
                .symbolEffect(.bounce, value: state.hasFullDiskAccess)

            Text(state.hasFullDiskAccess ? "Full Disk Access is on" : "Give Mop Full Disk Access")
                .font(.title.bold())

            Text("macOS protects some folders, like other apps' containers, Mail and Safari data. Without Full Disk Access, Mop can't see leftovers stored there, so scans may miss files.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if !state.hasFullDiskAccess {
                VStack(alignment: .leading, spacing: 8) {
                    step(1, "Click **Open System Settings**.")
                    step(2, "Turn on **Mop** in the Full Disk Access list. If it isn't listed, click **+** and choose Mop.")
                    step(3, "Come back here. Mop checks again automatically.")
                }
                .padding(14)
                .background(.background.secondary, in: .rect(cornerRadius: 12))
            }

            HStack {
                Button(state.hasFullDiskAccess ? "Done" : "Not Now") { finish() }
                    .keyboardShortcut(.cancelAction)
                if !state.hasFullDiskAccess {
                    Button("Check Again") { state.refreshPermissions() }
                    Button("Open System Settings") { FullDiskAccess.openSettings() }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                }
            }
            .controlSize(.large)
        }
        .padding(28)
        .frame(width: 520)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            state.refreshPermissions()
        }
    }

    private func step(_ number: Int, _ text: LocalizedStringKey) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("\(number)").font(.caption.bold()).frame(width: 20, height: 20).background(Circle().fill(.quaternary))
            Text(text)
        }
    }

    private func finish() {
        UserDefaults.standard.set(true, forKey: Prefs.Key.fullDiskAccessOnboardingDone)
        dismiss()
    }
}
