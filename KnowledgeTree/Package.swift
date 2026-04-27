// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "KnowledgeTree",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "KnowledgeTree",
            path: "KnowledgeTree",
            resources: []
        )
    ]
)
