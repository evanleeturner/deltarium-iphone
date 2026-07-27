// swift-tools-version: 6.0
import PackageDescription

// The xtool app package: exactly ONE automatic library product (xtool packs the
// cwd package's single automatic library; a `type:` or a second product breaks
// selection), the iOS 17 floor matching EasyModelerKit, and the same explicit
// v6 language mode. SwiftUI and Swift Charts come from the darwin SDK at link
// time, never as package dependencies — EasyModelerKit is the only dependency,
// and it holds no platform code (pure-Double numerics, Linux-buildable).
let package = Package(
  name: "EasyModelerApp",
  platforms: [.iOS(.v17)],
  products: [
    .library(name: "EasyModelerApp", targets: ["EasyModelerApp"])
  ],
  dependencies: [
    .package(path: "../EasyModelerKit")
  ],
  targets: [
    .target(
      name: "EasyModelerApp",
      dependencies: [
        .product(name: "EasyModelerKit", package: "EasyModelerKit")
      ],
      swiftSettings: [.swiftLanguageMode(.v6)]
    )
  ]
)
