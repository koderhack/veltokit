// swift-tools-version: 5.9
import PackageDescription

/// Stores `package` used by this scope.
let package = Package(
  name: "veltokit",
  platforms: [
    .iOS(.v16),
    .macOS(.v13),
  ],
  products: [
    .library(
      name: "VeltoKit",
      targets: ["VeltoKit"]
    ),
  ],
  targets: [
    .target(
      name: "VeltoKit",
      path: "VeltoKit",
      exclude: ["README.md"]
    ),
  ]
)
