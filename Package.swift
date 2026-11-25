// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "HerdrNotch",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "HerdrNotch", path: "Sources/HerdrNotch"),
        .testTarget(name: "HerdrNotchTests", dependencies: ["HerdrNotch"], path: "Tests/HerdrNotchTests"),
    ]
)
