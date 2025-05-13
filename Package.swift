// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "WJHelper",
    platforms: [.iOS(.v12)],
    products: [
        .library(
            name: "WJHelper",
            targets: ["WJHelper"]),
        .library(
            name: "WJHelper_Objc",
            targets: ["WJHelper_Objc"]),
    ],
    targets: [
        .target(
            name: "WJHelper",
            // 假如 Swift 库依赖本地 WJHelper_Objc 库，即在 dependencies 中配置
            dependencies: ["WJHelper_Objc"],
            path: "Source/WJHelper",
            swiftSettings: [.define("SPM_MODE")]
        ),
        .target(
            name: "WJHelper_Objc",
            path: "Source/WJHelper_Objc",
            publicHeadersPath: ""
        )
    ]
)



