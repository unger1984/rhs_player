// swift-tools-version: 5.9

import PackageDescription

let package = Package(
  name: "rhs_player",
  platforms: [
    .iOS(.v12)
  ],
  products: [
    .library(name: "rhs-player", targets: ["rhs_player"])
  ],
  dependencies: [],
  targets: [
    .target(
      name: "rhs_player",
      dependencies: [],
      resources: [
        .process("PrivacyInfo.xcprivacy")
      ]
    )
  ]
)
