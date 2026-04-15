// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Ledge",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Ledge", targets: ["Ledge"])
    ],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.0.0")
    ],
    targets: [
        .executableTarget(
            name: "Ledge",
            dependencies: [
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts")
            ],
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
