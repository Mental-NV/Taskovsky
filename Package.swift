// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Taskvovsky",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Taskvovsky", targets: ["Taskvovsky"])],
    targets: [
        .target(name: "TaskvovskyCore"),
        .executableTarget(name: "Taskvovsky", dependencies: ["TaskvovskyCore"]),
        .testTarget(name: "TaskvovskyCoreTests", dependencies: ["TaskvovskyCore"])
    ],
    swiftLanguageModes: [.v5]
)
