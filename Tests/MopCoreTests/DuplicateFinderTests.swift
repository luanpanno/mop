import Foundation
import Testing
@testable import MopCore

struct DuplicateFinderTests {
    @Test func groupsIdenticalFilesOnly() {
        let tmp = TempDir()
        tmp.file("a/photo.jpg", bytes: 200_000, fill: 7)
        tmp.file("b/photo copy.jpg", bytes: 200_000, fill: 7)
        tmp.file("c/other.jpg", bytes: 200_000, fill: 8)      // same size, different content
        tmp.file("d/small.txt", bytes: 10, fill: 7)            // below minimum size

        let groups = DuplicateFinder(minimumSize: 100_000).scan(tmp.url)

        #expect(groups.count == 1)
        #expect(Set(groups[0].map(\.name)) == ["photo.jpg", "photo copy.jpg"])
        #expect(DuplicateFinder.wasted(groups[0]) > 0)
    }

    @Test func detectsDifferenceAfterFirstChunk() {
        let tmp = TempDir()
        var first = Data(repeating: 1, count: 200_000)
        var second = first
        second[150_000] = 2
        first[0] = 1
        try! first.write(to: tmp.url.appendingPathComponent("one.bin"))
        try! second.write(to: tmp.url.appendingPathComponent("two.bin"))

        #expect(DuplicateFinder(minimumSize: 1).scan(tmp.url).isEmpty)
    }
}
