// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "SquirrelTests",
  platforms: [.macOS(.v13)],
  targets: [
    .target(
      name: "SquirrelCore",
      path: "sources",
      sources: ["SquirrelIndicator.swift"]
    ),
    .testTarget(
      name: "SquirrelTests",
      dependencies: ["SquirrelCore"],
      path: "Tests"
    ),
  ]
)
