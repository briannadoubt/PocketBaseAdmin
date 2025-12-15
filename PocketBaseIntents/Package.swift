// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PocketBaseIntents",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
        .watchOS(.v11),
        .visionOS(.v2)
    ],
    products: [
        .library(
            name: "PocketBaseIntents",
            targets: ["PocketBaseIntents"]
        ),
    ],
    dependencies: [
        .package(
            path: "../../PocketBase"
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
                .product(name: "PocketBase", package: "PocketBase"),
                .product(name: "PocketBaseAdmin", package: "PocketBase"),
                .product(name: "KeychainAccess", package: "KeychainAccess")
            ]
        ),
    ]
)
