// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FanficPairings",
    platforms: [.macOS("15.0")],
    products: [
        .executable(name: "FanficPairings", targets: ["FanficPairings"]),
    ],
    targets: [
        // Reading EPUB/PDF files, first pages, pairings, IDs, the library file and search. No UI.
        .target(name: "FanficCore"),
        // The SwiftUI Mac app.
        .executableTarget(name: "FanficPairings", dependencies: ["FanficCore"]),
        .testTarget(name: "FanficCoreTests", dependencies: ["FanficCore"]),
    ]
)
