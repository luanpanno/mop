import AppKit
import SwiftUI

/// Owns the main and settings windows. The Dock icon is shown only while one of them is open.
@MainActor
final class WindowManager: NSObject, NSWindowDelegate {
    private let state: AppState
    private let router: AppRouter
    private var mainWindow: NSWindow?
    private var settingsWindow: NSWindow?

    init(state: AppState, router: AppRouter) {
        self.state = state
        self.router = router
    }

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
        present(mainWindow)
    }

    func showSettings() {
        if settingsWindow == nil {
            let hosting = NSHostingController(rootView: SettingsView().environment(state).environment(router))
            hosting.sizingOptions = [.preferredContentSize]
            let window = NSWindow(contentViewController: hosting)
            window.styleMask = [.titled, .closable]
            window.title = "Mop Settings"
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.center()
            settingsWindow = window
        }
        present(settingsWindow)
    }

    private func present(_ window: NSWindow?) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        // Wait for the window to actually disappear before checking.
        DispatchQueue.main.async { [weak self] in
            MainActor.assumeIsolated { self?.updateActivationPolicy() }
        }
    }

    private func updateActivationPolicy() {
        let anyVisible = [mainWindow, settingsWindow].contains { $0?.isVisible == true }
        if !anyVisible {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
