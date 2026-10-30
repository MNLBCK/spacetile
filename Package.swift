// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "spacetile",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "spacetile", targets: ["SpaceTile"])
    ],
    targets: [
        .executableTarget(
            name: "SpaceTile",
            path: "Sources/SpaceTile"
        )
    ]
)
