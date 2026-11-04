import AppKit

// AppKit lifecycle (instead of SwiftUI `App`) gives full control over the
// status item, the Dock icon policy and the main/settings windows.
let delegate = AppDelegate()
NSApplication.shared.delegate = delegate
NSApplication.shared.run()
