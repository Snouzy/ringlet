// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ringlet",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "RingletCore"),
        .executableTarget(name: "RingletApp", dependencies: ["RingletCore"]),
        .testTarget(name: "RingletCoreTests", dependencies: ["RingletCore"]),
    ]
)
