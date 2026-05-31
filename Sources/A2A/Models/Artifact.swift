import Foundation
import StructuredDataCore

// MARK: - Artifact

/// タスクのアーティファクト（成果物）
///
/// エージェントがタスク処理中に生成した成果物を表現します。
public struct Artifact: Codable, Sendable, Equatable {
    /// アーティファクト名
    public let name: String?

    /// アーティファクトの説明
    public let description: String?

    /// アーティファクトのパート
    public let parts: [Part]

    /// インデックス
    public let index: Int?

    /// 最終チャンクかどうか
    public let lastChunk: Bool?

    /// メタデータ
    public let metadata: [String: StructuredValue]?

    public init(
        name: String? = nil,
        description: String? = nil,
        parts: [Part],
        index: Int? = nil,
        lastChunk: Bool? = nil,
        metadata: [String: StructuredValue]? = nil
    ) {
        self.name = name
        self.description = description
        self.parts = parts
        self.index = index
        self.lastChunk = lastChunk
        self.metadata = metadata
    }
}
