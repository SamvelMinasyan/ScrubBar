// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ScrubBar",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "ScrubBarCore", targets: ["ScrubBarCore"]),
        .executable(name: "ScrubBar", targets: ["ScrubBar"]),
        .executable(name: "ScrubBarCLI", targets: ["ScrubBarCLI"]),
        .executable(name: "ScrubBarVerifier", targets: ["ScrubBarVerifier"]),
    ],
    targets: [
        .target(
            name: "ScrubBarCore",
            dependencies: [],
            path: "Sources/ScrubBarCore"),
        .executableTarget(
            name: "ScrubBar",
            dependencies: ["ScrubBarCore"],
            path: "Sources/ScrubBar"),
        .executableTarget(
            name: "ScrubBarCLI",
            dependencies: ["ScrubBarCore"],
            path: "Sources/ScrubBarCLI"),
        .executableTarget(
            name: "ScrubBarVerifier",
            dependencies: ["ScrubBarCore"],
            path: "Sources/ScrubBarVerifier"),
        .testTarget(
            name: "ScrubBarTests",
            dependencies: ["ScrubBarCore"]),
    ]
)
