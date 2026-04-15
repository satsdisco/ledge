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
        )
        // NOTE: Test target temporarily disabled. The Command Line Tools
        // toolchain does not ship XCTest/swift-testing modules in a way
        // SwiftPM can resolve. Re-enable once full Xcode is installed
        // (or when we promote to Ledge.xcodeproj in Phase 3+).
        // Tests remain on disk at Tests/LedgeTests/.
    ]
)
