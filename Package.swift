// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "OpenUpdater",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "OpenUpdater", targets: ["OpenUpdater"]),
        .executable(name: "openupdater-cli", targets: ["openupdater-cli"]),
    ],
    targets: [
        .target(name: "OpenUpdater", resources: [.process("Resources")]),
        .executableTarget(name: "openupdater-cli"),
        .testTarget(name: "OpenUpdaterTests", dependencies: ["OpenUpdater"]),
    ]
)
