import Observation

/// Navigation and app-level actions, usable from SwiftUI views (window and popover).
@Observable
@MainActor
final class AppRouter {
    @ObservationIgnored var openMainHandler: (SidebarSection?) -> Void = { _ in }
    @ObservationIgnored var openSettingsHandler: () -> Void = {}
    @ObservationIgnored var closePopoverHandler: () -> Void = {}
    @ObservationIgnored var quickCleanHandler: () -> Void = {}

    func openMain(_ section: SidebarSection? = nil) {
        closePopoverHandler()
        openMainHandler(section)
    }

    func openSettings() {
        closePopoverHandler()
        openSettingsHandler()
    }

    func quickClean() {
        closePopoverHandler()
        quickCleanHandler()
    }
}
