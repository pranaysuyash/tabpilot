// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ChromeTabManager",
    platforms: [.macOS(.v13)],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "ChromeTabManager",
            exclude: [
                "Recovery",
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
