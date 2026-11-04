import Foundation

/// Capacity numbers for a volume (defaults to the startup disk).
public struct DiskInfo: Sendable, Equatable, Codable {
    public var total: Int64
    /// Space that is free right now.
    public var available: Int64
    /// Free space including what macOS can purge on demand (APFS snapshots, iCloud caches…).
    public var availableForImportantUsage: Int64

    public init(total: Int64, available: Int64, availableForImportantUsage: Int64) {
        self.total = total
        self.available = available
        self.availableForImportantUsage = max(available, availableForImportantUsage)
    }

    public var used: Int64 { max(0, total - available) }
    public var purgeable: Int64 { max(0, availableForImportantUsage - available) }
    public var usedFraction: Double { total > 0 ? Double(used) / Double(total) : 0 }
    public var purgeableFraction: Double { total > 0 ? Double(purgeable) / Double(total) : 0 }
}

public enum DiskInfoService {
    public static func current(volume: URL = URL(fileURLWithPath: "/")) throws -> DiskInfo {
        let values = try volume.resourceValues(forKeys: [
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey,
        ])
        let available = Int64(values.volumeAvailableCapacity ?? 0)
        return DiskInfo(
            total: Int64(values.volumeTotalCapacity ?? 0),
            available: available,
            availableForImportantUsage: values.volumeAvailableCapacityForImportantUsage ?? available
        )
    }
}
