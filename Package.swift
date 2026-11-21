// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Taskovsky",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .executable(name: "Taskovsky", targets: ["Taskovsky"]),
        .library(name: "TaskovskyDomain", targets: ["TaskovskyDomain"]),
        .library(name: "TaskovskyClipboard", targets: ["TaskovskyClipboard"]),
        .library(name: "TaskovskyWorkspace", targets: ["TaskovskyWorkspace"])
    ],
    targets: [
        .target(name: "TaskovskyDomain"),
        .target(name: "TaskovskyWorkspace", dependencies: ["TaskovskyDomain"]),
        .target(name: "TaskovskyClipboard", dependencies: ["TaskovskyDomain"]),
        .target(name: "TaskovskyCore", dependencies: ["TaskovskyDomain", "TaskovskyWorkspace"]),
        .executableTarget(name: "Taskovsky", dependencies: ["TaskovskyCore", "TaskovskyClipboard"]),
        .testTarget(name: "TaskovskyMacTests", dependencies: ["Taskovsky"]),
        .testTarget(name: "TaskovskyCoreTests", dependencies: ["TaskovskyCore", "TaskovskyClipboard"]),
        .testTarget(name: "TaskovskyDomainTests", dependencies: ["TaskovskyDomain"]),
        .testTarget(name: "TaskovskyWorkspaceTests", dependencies: ["TaskovskyDomain", "TaskovskyWorkspace"])
    ],
    swiftLanguageModes: [.v5]
)
