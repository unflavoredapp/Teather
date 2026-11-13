// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TetherlessHelper",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "tetherless-helper", targets: ["TetherlessHelper"])],
    targets: [
        .executableTarget(name: "TetherlessHelper")
    ]
)
