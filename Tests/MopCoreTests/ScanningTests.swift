import Foundation
import Testing
@testable import MopCore

struct ScanningTests {
    @Test func sizesFoldersRecursively() {
        let tmp = TempDir()
        tmp.file("x/1.bin", bytes: 100_000)
        tmp.file("x/y/2.bin", bytes: 100_000)
        let size = DirectorySizer.size(of: tmp.url.appendingPathComponent("x"))
        #expect(size >= 200_000)
    }

    @Test func missingFolderHasNoChildren() async {
        let items = await DirectorySizer.sizedChildren(of: URL(fileURLWithPath: "/nonexistent/\(UUID())"))
        #expect(items.isEmpty)
    }

    @Test func cleanupRespectsExclusions() async {
        let tmp = TempDir()
        tmp.file("Caches/com.foo.app/a", bytes: 50_000)
        tmp.file("Caches/com.apple.Music/a", bytes: 50_000)
        tmp.file("Caches/Homebrew/a", bytes: 50_000)
        let caches = tmp.url.appendingPathComponent("Caches")
        let category = CleanupCategory(
            id: "test", name: "Test", detail: "", symbol: "", isSafeForAutoClean: true,
            folders: [caches], excluded: [caches.appendingPathComponent("Homebrew")], excludedNamePrefixes: ["com.apple."]
        )

        let result = await CleanupScanner.scan(category)

        #expect(result.items.map(\.name) == ["com.foo.app"])
        #expect(result.total > 0)
    }

    @Test func largeFileFinderAppliesThresholdAndAge() {
        let tmp = TempDir()
        let big = tmp.file("big.mov", bytes: 2_000_000)
        tmp.file("small.txt", bytes: 1000)
        let old = Date(timeIntervalSinceNow: -400 * 86_400)
        try! FileManager.default.setAttributes([.modificationDate: old], ofItemAtPath: big.path)

        #expect(LargeFileFinder(minimumSize: 1_000_000).scan(tmp.url).map(\.name) == ["big.mov"])
        let unusedForAYear = LargeFileFinder(minimumSize: 1_000_000, unusedSince: Date(timeIntervalSinceNow: -365 * 86_400))
        #expect(unusedForAYear.scan(tmp.url).map(\.name) == ["big.mov"])
        let unusedForTwoYears = LargeFileFinder(minimumSize: 1_000_000, unusedSince: Date(timeIntervalSinceNow: -730 * 86_400))
        #expect(unusedForTwoYears.scan(tmp.url).isEmpty)
    }

    @Test func diskInfoMath() throws {
        let info = DiskInfo(total: 1000, available: 200, availableForImportantUsage: 300)
        #expect(info.used == 800)
        #expect(info.purgeable == 100)
        #expect(info.usedFraction == 0.8)
        let real = try DiskInfoService.current()
        #expect(real.total > 0 && real.available > 0)
    }

    @Test func catalogCategoriesHaveUniqueIDs() {
        let ids = CleanupCatalog.all().map(\.id)
        #expect(Set(ids).count == ids.count)
        #expect(CleanupCatalog.all().first { $0.id == "trash" }?.isSafeForAutoClean == false)
    }
}
