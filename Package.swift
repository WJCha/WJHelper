// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription


let package = Package(
    name: "WJHelper",
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "WJHeaderPageView",
            targets: ["WJHeaderPageView"]),
        .library(
            name: "PopupScheduler",
            targets: ["PopupScheduler"]),
        .library(
            name: "CollectionViewLayout",
            targets: ["CollectionViewLayout"]),
        .library(
            name: "WJPhotoTool",
            targets: ["WJPhotoTool"]),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "WJHeaderPageView"),
        .target(
            name: "CollectionViewLayout"),
        .target(
            name: "PopupScheduler"),
        .target(
            name: "WJPhotoTool"),
    ]
)
