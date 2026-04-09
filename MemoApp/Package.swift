// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MemoApp",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "MemoApp",
            path: "MemoApp",
            resources: []
        )
    ]
)
