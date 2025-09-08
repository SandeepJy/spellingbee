// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SpellingBeeShared",
    platforms: [
        .iOS(.v14)
    ],
    products: [
        .library(
            name: "SpellingBeeShared",
            targets: ["SpellingBeeShared"]
        ),
    ],
    targets: [
        .binaryTarget(
            name: "SpellingBeeShared",
            path: "shared/build/cocoapods/publish/debug/shared.xcframework"
        )
    ]
)
