// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Spoke",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "Spoke", path: "Sources/Spoke")
    ]
)
