// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ChromeTabManager",
    // Note: This package requires macOS 14+ due to APIs/features used by the app.
    platforms: [.macOS(.v14)],
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
