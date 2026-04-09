// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "VideoClipper",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "VideoClipper",
            path: "VideoClipper",
            resources: []
        )
    ]
)
