// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FanficEngine",
    platforms: [.macOS("15.0")],
    products: [
        .executable(name: "FanficEngine", targets: ["FanficEngine"]),
    ],
    dependencies: [
        // The updater (SPEC section 10): the app's only third-party code and its only network code.
        // One exact version (2.6.4 or later: earlier versions have a signature bypass, CVE-2025-0509).
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.1"),
    ],
    targets: [
        // Reading EPUB/PDF files, first pages, pairings, IDs, the library file and search. No UI, no network.
        .target(name: "FanficCore"),
        // The SwiftUI Mac app.
        .executableTarget(name: "FanficEngine", dependencies: ["FanficCore", .product(name: "Sparkle", package: "Sparkle")]),
        .testTarget(name: "FanficCoreTests", dependencies: ["FanficCore"]),
    ]
)
