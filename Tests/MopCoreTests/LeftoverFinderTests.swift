import Foundation
import Testing
@testable import MopCore

struct LeftoverMatchingTests {
    @Test(arguments: [
        "com.foo.editor", "com.foo.editor.plist", "com.foo.editor.savedState",
        "com.foo.editor.helper", "ABCDE12345.com.foo.editor", "group.com.foo.editor",
        "COM.FOO.EDITOR.binarycookies",
    ])
    func bundleIDMatchesAreExact(name: String) {
        #expect(LeftoverFinder.match(name: name, bundleID: "com.foo.editor", appName: "Editor", teamID: nil) == .exact)
    }

    @Test(arguments: ["com.foo.editorpro", "com.foo", "com.bar.editor.x", "Other"])
    func unrelatedNamesDoNotMatch(name: String) {
        #expect(LeftoverFinder.match(name: name, bundleID: "com.foo.editor", appName: "Super Editor", teamID: nil) == nil)
    }

    @Test func appNameMatchIsOnlyPossible() {
        #expect(LeftoverFinder.match(name: "Super Editor", bundleID: "com.foo.editor", appName: "Super Editor", teamID: nil) == .possible)
        #expect(LeftoverFinder.match(name: "supereditor", bundleID: nil, appName: "Super Editor", teamID: nil) == .possible)
    }

    @Test func shortAppNamesAreIgnored() {
        #expect(LeftoverFinder.match(name: "Go", bundleID: nil, appName: "Go", teamID: nil) == nil)
    }

    @Test func teamPrefixIsOnlyPossible() {
        #expect(LeftoverFinder.match(name: "ABCDE12345.shared", bundleID: "com.foo.editor", appName: "Editor", teamID: "ABCDE12345") == .possible)
    }

    @Test func findsLeftoversInRoots() {
        let tmp = TempDir()
        tmp.file("Preferences/com.foo.editor.plist", bytes: 4096)
        tmp.file("Application Support/com.foo.editor/data.db", bytes: 8192)
        tmp.file("Application Support/Super Editor/settings.json", bytes: 4096)
        tmp.file("Caches/com.other.app/cache", bytes: 4096)
        let finder = LeftoverFinder(searchRoots: ["Preferences", "Application Support", "Caches"].map { tmp.url.appendingPathComponent($0) })

        let found = finder.find(bundleID: "com.foo.editor", appName: "Super Editor")

        #expect(Set(found.map(\.url.lastPathComponent)) == ["com.foo.editor.plist", "com.foo.editor", "Super Editor"])
        #expect(found.first?.confidence == .exact)
        #expect(found.last?.confidence == .possible)
        #expect(found.allSatisfy { $0.size > 0 })
    }
}
