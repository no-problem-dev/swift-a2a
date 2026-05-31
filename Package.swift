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
        // 規定プロトコル（A2A データモデル + ProtoJSON シリアライズ）だけを使いたいとき
        .library(name: "A2ACore", targets: ["A2ACore"]),
        // REST（HTTP+JSON）バインディングのクライアント
        .library(name: "A2AClientREST", targets: ["A2AClientREST"]),
        // JSON-RPC バインディングのクライアント
        .library(name: "A2AClientJSONRPC", targets: ["A2AClientJSONRPC"]),
    ],
    dependencies: [
        .package(url: "https://github.com/no-problem-dev/swift-structured-data.git", from: "1.3.0"),
    ],
    targets: [
        // 規定プロトコル層: データモデル + ProtoJSON Codable + 構築ビルダー
        .target(
            name: "A2ACore",
            dependencies: [
                .product(name: "StructuredDataCore", package: "swift-structured-data"),
            ]
        ),
        // クライアント共通基盤（非公開）: A2AClient actor / A2ATransport 抽象 / SSE / 認証 / AgentCard 取得
        .target(
            name: "A2AClientCore",
            dependencies: ["A2ACore"]
        ),
        // REST バインディング実装
        .target(
            name: "A2AClientREST",
            dependencies: ["A2AClientCore"]
        ),
        // JSON-RPC バインディング実装
        .target(
            name: "A2AClientJSONRPC",
            dependencies: ["A2AClientCore"]
        ),
        .testTarget(
            name: "A2ACoreTests",
            dependencies: ["A2ACore"],
            resources: [.copy("Fixtures")]
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
