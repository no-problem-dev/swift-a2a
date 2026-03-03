// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "swift-a2a",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "A2A", targets: ["A2A"]),
    ],
    targets: [
        .target(name: "A2A"),
    ]
)
