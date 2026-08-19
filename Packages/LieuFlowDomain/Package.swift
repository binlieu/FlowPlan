// swift-tools-version: 6.0
import PackageDescription

// LieuFlowDomain is the pure financial core of LieuFlow.
//
// HARD CONSTRAINT: this target must never import SwiftUI, SwiftData, CoreData,
// UIKit or Observation. It takes plain value types in and returns plain value
// types out, so the exact same engine can power the iPhone dashboard, a
// WidgetKit extension, Apple Watch, Shortcuts and the What-If simulator.
// It is testable with `swift test` alone — no simulator, no store, no host app.
let package = Package(
    name: "LieuFlowDomain",
    platforms: [
        .iOS(.v18),
        .macOS(.v14),
        .watchOS(.v10)
    ],
    products: [
        .library(name: "LieuFlowDomain", targets: ["LieuFlowDomain"])
    ],
    targets: [
        .target(name: "LieuFlowDomain"),
        .testTarget(name: "LieuFlowDomainTests", dependencies: ["LieuFlowDomain"])
    ]
)
