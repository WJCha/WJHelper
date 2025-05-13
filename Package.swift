// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "WJHelper",
    platforms: [.iOS(.v12)],
    products: [
        .library(
            name: "WJHelper_Objc",
            targets: ["WJHelper_Objc"]),
    ],
    targets: [
        .target(
            name: "WJHelper_Objc",
            path: "Source/WJHelper_Objc",
            publicHeadersPath: ""
        ),
    ]
)



