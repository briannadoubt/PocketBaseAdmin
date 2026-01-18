// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "PocketBaseIntents",
    platforms: [
        .iOS(.v26),
        .macOS(.v26),
        .watchOS(.v26),
        .visionOS(.v26)
    ],
    products: [
        .library(
            name: "PocketBaseIntents",
            targets: ["PocketBaseIntents"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/briannadoubt/pocketbase",
            .upToNextMajor(from: "0.2.3")
        ),
        .package(
            url: "https://github.com/kishikawakatsumi/KeychainAccess",
            .upToNextMajor(from: "4.2.2")
        )
    ],
    targets: [
        .target(
            name: "PocketBaseIntents",
            dependencies: [
                .product(name: "PocketBase", package: "pocketbase"),
                .product(name: "PocketBaseAdmin", package: "pocketbase"),
                .product(name: "KeychainAccess", package: "KeychainAccess")
            ]
        ),
    ]
)
