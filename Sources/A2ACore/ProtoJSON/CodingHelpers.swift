/// ProtoJSON（proto3 JSON マッピング）のセマンティクスを簡潔に表現するコンテナ拡張。
///
/// - デコード: 欠落フィールドは proto3 の既定値（空文字列・0・`false`・空配列・`UNSPECIFIED`）に補完し、例外を投げない。
/// - エンコード: 既定値と等しいフィールドは出力しない（`MessageToDict` 既定挙動に一致）。
extension KeyedDecodingContainer {
    /// 任意 repeated フィールド。欠落なら空配列。
    func decodeArray<T: Decodable>(_ type: T.Type = T.self, forKey key: Key) throws -> [T] {
        try decodeIfPresent([T].self, forKey: key) ?? []
    }

    /// bool。欠落なら `false`。
    func decodeBool(forKey key: Key) throws -> Bool {
        try decodeIfPresent(Bool.self, forKey: key) ?? false
    }

    /// string。欠落なら空文字列。
    func decodeString(forKey key: Key) throws -> String {
        try decodeIfPresent(String.self, forKey: key) ?? ""
    }

    /// int。欠落なら 0。
    func decodeInt(forKey key: Key) throws -> Int {
        try decodeIfPresent(Int.self, forKey: key) ?? 0
    }

    /// proto enum。欠落・未知値なら `.unspecified`。
    func decodeProtoEnum<E: ProtoEnum>(_ type: E.Type = E.self, forKey key: Key) throws -> E {
        try decodeIfPresent(E.self, forKey: key) ?? .unspecified
    }

    /// 必須 ID。欠落なら空 ID。
    func decodeID<I: A2AIdentifier>(_ type: I.Type = I.self, forKey key: Key) throws -> I {
        try decodeIfPresent(I.self, forKey: key) ?? I("")
    }

    /// 任意 ID。欠落または空文字列なら `nil`。
    func decodeOptionalID<I: A2AIdentifier>(_ type: I.Type = I.self, forKey key: Key) throws -> I? {
        guard let id = try decodeIfPresent(I.self, forKey: key), !id.rawValue.isEmpty else { return nil }
        return id
    }
}

extension KeyedEncodingContainer {
    /// 非空のときだけ encode。
    mutating func encodeIfNonEmpty<T: Encodable>(_ value: [T], forKey key: Key) throws {
        if !value.isEmpty { try encode(value, forKey: key) }
    }

    /// 非空マップのときだけ encode。
    mutating func encodeIfNonEmpty<V: Encodable>(_ value: [String: V], forKey key: Key) throws {
        if !value.isEmpty { try encode(value, forKey: key) }
    }

    /// 非空文字列のときだけ encode。
    mutating func encodeIfNonEmpty(_ value: String, forKey key: Key) throws {
        if !value.isEmpty { try encode(value, forKey: key) }
    }

    /// 非空 ID のときだけ encode。
    mutating func encodeIfNonEmpty<I: A2AIdentifier>(_ value: I, forKey key: Key) throws {
        if !value.rawValue.isEmpty { try encode(value, forKey: key) }
    }

    /// 0 以外のときだけ encode。
    mutating func encodeIfNonZero(_ value: Int, forKey key: Key) throws {
        if value != 0 { try encode(value, forKey: key) }
    }

    /// `true` のときだけ encode。
    mutating func encodeIfTrue(_ value: Bool, forKey key: Key) throws {
        if value { try encode(value, forKey: key) }
    }

    /// `.unspecified` 以外のときだけ encode。
    mutating func encode<E: ProtoEnum>(proto value: E, forKey key: Key) throws {
        if value != .unspecified { try encode(value, forKey: key) }
    }
}
