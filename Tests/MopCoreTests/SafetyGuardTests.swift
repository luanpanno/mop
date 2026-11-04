import Foundation
import Testing
@testable import MopCore

struct SafetyGuardTests {
    let home = URL(fileURLWithPath: "/Users/tester")
    var safety: SafetyGuard { SafetyGuard(home: home, ownBundle: URL(fileURLWithPath: "/Applications/Mop.app")) }

    @Test(arguments: [
        "/", "/System/Library/Caches", "/usr/local/bin/tool", "/Applications", "/Library/Caches",
        "/Users/tester", "/Users/tester/Library", "/Users/tester/Library/Caches", "/Users/tester/Documents",
        "/Applications/Mop.app", "/Applications/Mop.app/Contents/MacOS/Mop",
    ])
    func blocksProtectedPaths(path: String) {
        #expect(safety.check(URL(fileURLWithPath: path)) != .allowed)
    }

    @Test(arguments: [
        "/Users/tester/Library/Caches/com.foo.editor", "/Users/tester/Library/Preferences/com.foo.editor.plist",
        "/Users/tester/Downloads/big.dmg", "/Applications/Editor.app", "/Library/LaunchDaemons/com.foo.helper.plist",
    ])
    func allowsRegularItems(path: String) {
        #expect(safety.check(URL(fileURLWithPath: path)) == .allowed)
    }

    @Test func blocksAppleApps() {
        // Safari is a real Apple app on every Mac.
        #expect(SafetyGuard().check(URL(fileURLWithPath: "/Applications/Safari.app")) != .allowed)
    }
}
