// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Harmonium",
    platforms: [.macOS(.v26)],   // Liquid Glass (.glassEffect) requires macOS 26
    products: [
        .executable(name: "Harmonium", targets: ["Harmonium"])
    ],
    targets: [
        .executableTarget(
            name: "Harmonium",
            path: "Sources/Harmonium",
            resources: [
                .copy("Resources")
            ],
            swiftSettings: [
                // Keep Swift 5 language mode so existing concurrency annotations stay valid.
                .swiftLanguageMode(.v5)
            ],
            linkerSettings: [
                .linkedFramework("IOKit")
            ]
        )
    ]
)
