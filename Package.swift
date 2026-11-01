// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FanficEngine",
    platforms: [.macOS("15.0")],
    products: [
        .executable(name: "FanficEngine", targets: ["FanficEngine"]),
    ],
    targets: [
        // Reading EPUB/PDF files, first pages, pairings, IDs, the library file and search. No UI.
        .target(name: "FanficCore"),
        // The SwiftUI Mac app.
        .executableTarget(name: "FanficEngine", dependencies: ["FanficCore"]),
        .testTarget(name: "FanficCoreTests", dependencies: ["FanficCore"]),
    ]
)
