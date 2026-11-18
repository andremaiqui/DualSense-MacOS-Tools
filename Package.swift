// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "DSUpdater",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "DSUpdater",
            path: "Sources/DSUpdater",
            resources: [.process("Resources")]
        )
    ],
    swiftLanguageModes: [.v5]
)
