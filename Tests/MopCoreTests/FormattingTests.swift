import Testing
@testable import MopCore

@Test func formatsBytes() {
    #expect(Int64(0).formattedBytes == "Zero KB")
}
