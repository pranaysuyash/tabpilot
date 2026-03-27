// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "ChromeTabManager",
    // Note: This package requires macOS 15+ due to APIs/features used by the app.
    platforms: [.macOS(.v15)],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "ChromeTabManager",
            exclude: [
                "AppModels.swift"
            ],
            swiftSettings: [.enableExperimentalFeature("StrictConcurrency")]
        ),

        .testTarget(
            name: "ChromeTabManagerTests",
            dependencies: ["ChromeTabManager"],
            swiftSettings: [.enableExperimentalFeature("StrictConcurrency")]
        )
    ]
)
