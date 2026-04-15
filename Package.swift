// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Ledge",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Ledge", targets: ["Ledge"])
    ],
    targets: [
        .executableTarget(
            name: "Ledge",
            path: "Sources/Ledge",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "LedgeTests",
            dependencies: ["Ledge"],
            path: "Tests/LedgeTests"
        )
    ]
)
