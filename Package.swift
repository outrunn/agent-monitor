// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AgentMonitor",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "AgentMonitor", targets: ["AgentMonitor"])
    ],
    targets: [
        .executableTarget(
            name: "AgentMonitor",
            path: "AgentMonitor",
            exclude: ["Assets.xcassets", "AgentMonitor.entitlements"]
        )
    ]
)
