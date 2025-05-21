// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "WJHelper",
    platforms: [.iOS(.v12)],
    products: [
        .library(
            name: "WJHeaderPageView",
            targets: ["WJHeaderPageView"]),
    ],
    targets: [
        .target(
            name: "WJHeaderPageView", path: "Sources/WJHeaderPageView")
    ]
)
