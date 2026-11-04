// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FXMicBridge",
    platforms: [.macOS("15.0")],
    products: [.executable(name: "FXMicBridge", targets: ["FXMicBridge"])],
    targets: [
        .target(name: "FXMicCore"),
        .executableTarget(name: "FXMicBridge", dependencies: ["FXMicCore"]),
        .testTarget(name: "FXMicCoreTests", dependencies: ["FXMicCore"])
    ]
)
