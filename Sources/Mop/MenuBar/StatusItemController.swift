import AppKit
import MopCore
import SwiftUI

/// The menu bar item. A left click toggles the popover; a right click (or control-click) shows a menu.
@MainActor
final class StatusItemController: NSObject {
    private let state: AppState
    private let router: AppRouter
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()

    init(state: AppState, router: AppRouter) {
        self.state = state
        self.router = router
        super.init()

        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "bubbles.and.sparkles", accessibilityDescription: "Mop")
            image?.isTemplate = true
            button.image = image
            button.imagePosition = .imageLeading
            button.target = self
            button.action = #selector(handleClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.toolTip = "Mop"
        }

        let hosting = NSHostingController(rootView: MenuBarPopoverView().environment(state).environment(router))
        hosting.sizingOptions = [.preferredContentSize]
        popover.contentViewController = hosting
        popover.behavior = .transient
        popover.animates = true

        observeState()
        NotificationCenter.default.addObserver(
            self, selector: #selector(defaultsChanged), name: UserDefaults.didChangeNotification, object: nil
        )
        updateTitle()
    }

    func closePopover() {
        popover.performClose(nil)
    }

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            showMenu()
        } else {
            togglePopover()
        }
    }

    private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            state.refreshDisk()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
            NSApp.activate()
        }
    }

    private func showMenu() {
        closePopover()
        guard let button = statusItem.button else { return }
        let menu = buildMenu()
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 5), in: button)
    }

    private func buildMenu() -> NSMenu {
        state.refreshDisk()
        let menu = NSMenu()
        menu.addItem(item("Open Mop", #selector(openMop)))
        menu.addItem(.separator())

        if let disk = state.disk {
            menu.addItem(info("\(disk.availableForImportantUsage.formattedBytes) available of \(disk.total.formattedBytes)", symbol: "internaldrive"))
        }
        menu.addItem(info("\(state.reclaimable.formattedBytes) can be freed", symbol: "sparkles"))
        menu.addItem(.separator())

        for section in SidebarSection.tools {
            let entry = item(section.title, #selector(openSection(_:)))
            entry.representedObject = section.rawValue
            entry.image = NSImage(systemSymbolName: section.symbol, accessibilityDescription: nil)
            menu.addItem(entry)
        }
        menu.addItem(.separator())
        menu.addItem(item("Quick Clean…", #selector(quickClean)))
        menu.addItem(item(state.isScanningCleanup ? "Scanning…" : "Rescan Now", #selector(rescan)))
        menu.addItem(.separator())
        menu.addItem(item("Settings…", #selector(openSettings), key: ","))
        menu.addItem(item("Quit Mop", #selector(quit), key: "q"))
        return menu
    }

    private func item(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    private func info(_ title: String, symbol: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        item.isEnabled = false
        return item
    }

    @objc private func openMop() { router.openMain() }
    @objc private func openSettings() { router.openSettings() }
    @objc private func quickClean() { router.quickClean() }
    @objc private func quit() { NSApp.terminate(nil) }
    @objc private func rescan() { Task { await state.scanCleanup() } }

    @objc private func openSection(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let section = SidebarSection(rawValue: raw) else { return }
        router.openMain(section)
    }

    // MARK: Free-space title next to the icon

    private func observeState() {
        withObservationTracking {
            _ = state.disk
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.updateTitle()
                self?.observeState()
            }
        }
    }

    @objc private func defaultsChanged() {
        updateTitle()
    }

    private func updateTitle() {
        guard let button = statusItem.button else { return }
        let show = UserDefaults.standard.bool(forKey: Prefs.Key.showFreeSpaceInMenuBar)
        if show, let disk = state.disk {
            button.title = " " + disk.availableForImportantUsage.formattedBytes
        } else {
            button.title = ""
        }
    }
}
