import Foundation
import UserNotifications

/// Thin wrapper around user notifications. Disabled when running as a bare executable
/// (e.g. `swift run`), where UNUserNotificationCenter is unavailable.
@MainActor
enum Notifier {
    nonisolated static let sectionKey = "section"

    static var isAvailable: Bool {
        Bundle.main.bundleIdentifier != nil && Bundle.main.bundleURL.pathExtension == "app"
    }

    static func requestAuthorization() {
        guard isAvailable else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func post(id: String, title: String, body: String, section: SidebarSection? = nil) {
        guard isAvailable else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        if let section { content.userInfo = [sectionKey: section.rawValue] }
        let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
