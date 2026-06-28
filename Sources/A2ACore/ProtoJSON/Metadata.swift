import StructuredDataCore

/// `google.protobuf.Struct` の A2A 表現。任意の JSON オブジェクトを保持するメタデータ。
///
/// `Message`/`Task`/`Artifact`/`AgentExtension` などの `metadata`・`params` 等で使用する。
public typealias A2AMetadata = [String: StructuredValue]
