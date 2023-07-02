// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "Claveilleur",
  platforms: [
    .macOS(.v11)
  ],
  dependencies: [
    .package(
      url: "https://github.com/apple/swift-log.git",
      from: "1.5.0"
    ),
    .package(
      url: "https://github.com/apple/swift-argument-parser",
      from: "1.2.0"
    ),
  ],
  targets: [
    // Targets are the basic building blocks of a package, defining a module or a test suite.
    // Targets can depend on other targets in this package and products from dependencies.
    .executableTarget(
      name: "Claveilleur",
      dependencies: [
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        .product(name: "Logging", package: "swift-log"),
      ],
      path: "Sources"
    )
  ]
)
