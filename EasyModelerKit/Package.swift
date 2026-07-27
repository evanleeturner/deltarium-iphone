// swift-tools-version: 6.0
import PackageDescription

// EasyModelerKit is the pure Swift ODE engine — no UIKit, no SwiftUI, no
// network, no simd — so it builds and tests on Linux and in CI, exactly like
// ham-measure's HamKit and the IRS app's PenaltyKit. The SwiftUI + xtool app
// shell is a separate package under App/ (a later phase). The iOS 17 floor
// matches that coming shell; the explicit v6 language mode matches the swift
// crown. Arithmetic is plain Double (+ − × ÷) so Linux-x86 and iOS-ARM
// integrate bit-identically — the fidelity lane against the Python engine's
// port_reference fixtures.
let package = Package(
  name: "EasyModelerKit",
  platforms: [.iOS(.v17), .macOS(.v14)],
  products: [
    .library(name: "EasyModelerKit", targets: ["EasyModelerKit"])
  ],
  targets: [
    .target(
      name: "EasyModelerKit",
      swiftSettings: [.swiftLanguageMode(.v6)]
    ),
    .testTarget(
      name: "EasyModelerKitTests",
      dependencies: ["EasyModelerKit"],
      resources: [.copy("Fixtures")],
      swiftSettings: [.swiftLanguageMode(.v6)]
    ),
  ]
)
