// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "VideoTextExtractor",
    platforms: [
        .macOS(.v26),
        .iOS(.v26),
        .tvOS(.v26)
    ],
    products: [
        .library(
            name: "VideoTextExtractor",
            targets: ["VideoTextExtractor"]
        ),
    ],
    targets: [
        .target(
            name: "VideoTextExtractor",
            dependencies: []
        ),
        .testTarget(
            name: "VideoTextExtractorTests",
            dependencies: ["VideoTextExtractor"],
            resources: [
                .copy("Resources")
            ]
        ),
    ]
)
