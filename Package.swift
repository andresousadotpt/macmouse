// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MacMouse",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "MacMouse", targets: ["MacMouse"]),
    ],
    dependencies: [],
    targets: [
        .target(name: "MacMouseCore"),
        .executableTarget(
            name: "MacMouse",
            dependencies: ["MacMouseCore"],
            resources: [
                .process("Resources"),
            ]
        ),
        .testTarget(
            name: "MacMouseCoreTests",
            dependencies: ["MacMouseCore"]
        ),
    ]
)
