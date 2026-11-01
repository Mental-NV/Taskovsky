// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Taskovsky",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Taskovsky", targets: ["Taskovsky"])],
    targets: [
        .target(name: "TaskovskyCore"),
        .executableTarget(name: "Taskovsky", dependencies: ["TaskovskyCore"]),
        .testTarget(name: "TaskovskyCoreTests", dependencies: ["TaskovskyCore"])
    ],
    swiftLanguageModes: [.v5]
)
