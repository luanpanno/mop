import AppKit
import SwiftUI

/// Owns the main window. The Dock icon is shown only while it is open.
@MainActor
final class WindowManager: NSObject, NSWindowDelegate {
    private let state: AppState
    private let router: AppRouter
    private var mainWindow: NSWindow?

    init(state: AppState, router: AppRouter) {
        self.state = state
        self.router = router
    }

    var isMainWindowVisible: Bool { mainWindow?.isVisible == true }

    func showMain(section: SidebarSection? = nil) {
        if let section { state.section = section }
        if mainWindow == nil {
            let hosting = NSHostingController(rootView: MainView().environment(state).environment(router))
            hosting.sceneBridgingOptions = [.toolbars, .title]
            let window = NSWindow(contentViewController: hosting)
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
            window.title = "Mop"
            window.toolbarStyle = .unified
            window.setContentSize(NSSize(width: 1000, height: 660))
            window.minSize = NSSize(width: 820, height: 520)
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.center()
            window.setFrameAutosaveName("MopMainWindow")
            mainWindow = window
        }
        present(mainWindow!)
    }

    /// Brings the window to the front and gives it focus.
    ///
    /// Switching from `.accessory` (menu bar only) to `.regular` (Dock icon) doesn't take effect until
    /// the next run loop pass, and macOS ignores activation requests made before then. So activate now,
    /// then once more after the switch has gone through.
    private func present(_ window: NSWindow) {
        let wasAccessory = NSApp.activationPolicy() != .regular
        NSApp.setActivationPolicy(.regular)
        if window.isMiniaturized { window.deminiaturize(nil) }
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)

        guard wasAccessory else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            MainActor.assumeIsolated {
                NSApp.activate()
                window.makeKeyAndOrderFront(nil)
                window.orderFrontRegardless()
            }
        }
    }

    func windowWillClose(_ notification: Notification) {
        // Hide the Dock icon once the window is actually gone.
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                if NSApp.windows.allSatisfy({ !$0.isVisible || $0 is NSPanel || $0.level != .normal }) {
                    NSApp.setActivationPolicy(.accessory)
                }
            }
        }
    }
}
