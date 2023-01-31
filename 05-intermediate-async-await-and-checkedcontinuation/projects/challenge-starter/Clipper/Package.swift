// swift-tools-version:5.7

import PackageDescription

let package = Package(
    name: "Clipper",
    platforms: [.macOS(.v12)],
    dependencies: [],
    targets: [
        .executableTarget(name: "Clipper", dependencies: [])
    ]
)
