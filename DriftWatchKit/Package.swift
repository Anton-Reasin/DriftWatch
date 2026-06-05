// swift-tools-version: 6.0
import PackageDescription

// Local package that holds the domain core. The app target links it.
// Module boundaries are enforced by the compiler: a module can only reach what
// it explicitly depends on, so layers cannot quietly leak into each other.
let package = Package(
    name: "DriftWatchKit",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
    ],
    products: [
        .library(name: "SharedKit", targets: ["SharedKit"]),
    ],
    targets: [
        // Sendable value types shared across every layer. No dependencies.
        .target(name: "SharedKit"),
        .testTarget(name: "SharedKitTests", dependencies: ["SharedKit"]),
    ]
)
