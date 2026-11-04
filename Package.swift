// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Mop",
    platforms: [.macOS("26.0")],
    products: [
        .executable(name: "Mop", targets: ["Mop"]),
    ],
    targets: [
        // Pure logic: scanning, leftovers, cleanup rules, safety, removal. No UI.
        .target(name: "MopCore"),
        // The app: AppKit lifecycle + SwiftUI views, menu bar item, monitors.
        .executableTarget(name: "Mop", dependencies: ["MopCore"]),
        .testTarget(name: "MopCoreTests", dependencies: ["MopCore"]),
    ]
)
