// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "swift-a2a",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "A2A", targets: ["A2A"]),
    ],
    dependencies: [
        .package(url: "https://github.com/no-problem-dev/swift-structured-data.git", from: "1.3.0"),
    ],
    targets: [
        .target(name: "A2A", dependencies: [
            .product(name: "StructuredDataCore", package: "swift-structured-data"),
        ]),
    ]
)
