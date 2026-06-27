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
        // サーバ実装フレームワーク（AgentExecutor / RequestHandler / TaskStore など、トランスポート非依存）
        .library(name: "A2AServer", targets: ["A2AServer"]),
        // JSON-RPC バインディングのサーバ側ディスパッチャ（HTTP 非依存）
        .library(name: "A2AServerJSONRPC", targets: ["A2AServerJSONRPC"]),
        // REST（HTTP+JSON）バインディングのサーバ側ディスパッチャ（HTTP 非依存）
        .library(name: "A2AServerREST", targets: ["A2AServerREST"]),
        // in-process バインディング: 同一プロセス内で client(A2ATransport) ↔ server(RequestHandler) を型直結
        .library(name: "A2AInProcess", targets: ["A2AInProcess"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.4.0"),
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
        // サーバ実装フレームワーク（proto 非定義のリファレンス実装構造を写経、依存は A2ACore のみ）
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
        // JSON-RPC サーバ側ディスパッチャ: 封筒のデコード → RequestHandler 呼び出し → 封筒エンコード
        .target(
            name: "A2AServerJSONRPC",
            dependencies: ["A2AServer", "A2ACore"]
        ),
        .testTarget(
            name: "A2AServerJSONRPCTests",
            dependencies: ["A2AServerJSONRPC"]
        ),
        // REST サーバ側ディスパッチャ: (HTTP method, path, query, body) → RequestHandler 呼び出し
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
        // in-process バインディング: A2ATransport を RequestHandler 直結で実装（同一プロセス・型安全）
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
