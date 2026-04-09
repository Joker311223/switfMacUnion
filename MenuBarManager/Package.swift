// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MenuBarManager",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "MenuBarManager",
            path: "MenuBarManager",
            resources: []
        )
    ]
)
