// swift-tools-version: 6.3

import PackageDescription

// MARK: - LoreKit
// Personal toolkit of context-free SwiftUI components — pure shapes,
// view modifiers, helpers that don't know anything about any app's
// domain. The strict admission rule: no dependency on app state, no
// reach into anyone's environment, no domain types. Everything in
// here should be drop-in usable across every personal project.
//
// One library product for now; split into Lore<Shapes|UI|...> when
// the population grows enough to need shelves.
let package = Package(
    name: "LoreKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .watchOS(.v26),
    ],
    products: [
        .library(
            name: "LoreKit",
            targets: ["LoreKit"]
        ),
    ],
    targets: [
        .target(
            name: "LoreKit"
        ),
        .testTarget(
            name: "LoreKitTests",
            dependencies: ["LoreKit"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
