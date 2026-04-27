// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WebViewer",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "WebViewer",
            path: "WebViewer"
        )
    ]
)
