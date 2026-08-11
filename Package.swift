// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "swift-a2a",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
        .tvOS(.v17),
        .watchOS(.v10),
        .visionOS(.v1),
    ],
    products: [
        // The protocol itself: data model plus ProtoJSON serialization, and nothing else.
        .library(name: "A2ACore", targets: ["A2ACore"]),
        // Client speaking the HTTP+JSON binding.
        .library(name: "A2AClientREST", targets: ["A2AClientREST"]),
        // Client speaking the JSON-RPC 2.0 binding.
        .library(name: "A2AClientJSONRPC", targets: ["A2AClientJSONRPC"]),
        // Server framework: executor, request handler, task store. Transport-agnostic.
        .library(name: "A2AServer", targets: ["A2AServer"]),
        // Server-side dispatcher for the JSON-RPC binding. No HTTP dependency.
        .library(name: "A2AServerJSONRPC", targets: ["A2AServerJSONRPC"]),
        // Server-side dispatcher for the HTTP+JSON binding. No HTTP dependency.
        .library(name: "A2AServerREST", targets: ["A2AServerREST"]),
        // In-process binding: wires the client protocol straight to a server handler, no wire format.
        .library(name: "A2AInProcess", targets: ["A2AInProcess"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.4.0"),
        .package(url: "https://github.com/no-problem-dev/swift-structured-data.git", from: "3.0.0"),
    ],
    targets: [
        // Protocol layer: data model, ProtoJSON Codable conformances, message builder.
        .target(
            name: "A2ACore",
            dependencies: [
                .product(name: "StructuredDataCore", package: "swift-structured-data"),
            ]
        ),
        // Shared client plumbing, not published as a product: the client facade, the transport
        // protocol, SSE parsing, authentication, and agent-card lookup.
        .target(
            name: "A2AClientCore",
            dependencies: ["A2ACore"]
        ),
        // REST binding.
        .target(
            name: "A2AClientREST",
            dependencies: ["A2AClientCore"]
        ),
        // JSON-RPC binding.
        .target(
            name: "A2AClientJSONRPC",
            dependencies: ["A2AClientCore"]
        ),
        // Server framework. Its shape follows the reference implementation rather than the proto
        // definitions, which say nothing about server structure. Depends only on A2ACore.
        .target(
            name: "A2AServer",
            dependencies: ["A2ACore"]
        ),
        .testTarget(
            name: "A2ACoreTests",
            dependencies: ["A2ACore"],
            resources: [.copy("Fixtures")]
        ),
        .testTarget(
            name: "A2AServerTests",
            dependencies: ["A2AServer"]
        ),
        // JSON-RPC dispatcher: decode envelope, call the handler, encode the answer.
        .target(
            name: "A2AServerJSONRPC",
            dependencies: ["A2AServer", "A2ACore"]
        ),
        .testTarget(
            name: "A2AServerJSONRPCTests",
            dependencies: ["A2AServerJSONRPC"]
        ),
        // REST dispatcher: route (method, path, query, body) to a handler call.
        .target(
            name: "A2AServerREST",
            dependencies: [
                "A2AServer",
                "A2ACore",
                .product(name: "StructuredDataCore", package: "swift-structured-data"),
            ]
        ),
        .testTarget(
            name: "A2AServerRESTTests",
            dependencies: ["A2AServerREST"]
        ),
        // Both halves of the REST binding at once: what the client writes on the wire has to be
        // what the server reads back. Neither side's own tests can see a mismatch between them.
        .testTarget(
            name: "A2ARESTRoundTripTests",
            dependencies: ["A2AClientREST", "A2AServerREST"]
        ),
        // In-process binding: implements the transport protocol by calling a handler directly.
        .target(
            name: "A2AInProcess",
            dependencies: ["A2AClientCore", "A2AServer", "A2ACore"]
        ),
        .testTarget(
            name: "A2AInProcessTests",
            dependencies: ["A2AInProcess"]
        ),
        .testTarget(
            name: "A2AClientRESTTests",
            dependencies: ["A2AClientREST"]
        ),
        .testTarget(
            name: "A2AClientJSONRPCTests",
            dependencies: ["A2AClientJSONRPC"]
        ),
    ]
)
