// Container helpers that put proto3's JSON mapping rules in one place.
//
// Decoding: an absent field is not an error. It becomes the proto3 default — empty string, 0,
// false, empty array, UNSPECIFIED — because in proto3 a default-valued field and an absent one are
// the same thing on the wire.
//
// Encoding: a field equal to its default is omitted, matching what protobuf's own JSON writer does
// by default. The consequence worth knowing is that a required-looking field with an empty value
// simply does not appear in the output.
extension KeyedDecodingContainer {
    /// Decodes a repeated field, yielding an empty array when it is absent.
    func decodeArray<T: Decodable>(_ type: T.Type = T.self, forKey key: Key) throws -> [T] {
        try decodeIfPresent([T].self, forKey: key) ?? []
    }

    /// Decodes a bool, yielding `false` when it is absent.
    func decodeBool(forKey key: Key) throws -> Bool {
        try decodeIfPresent(Bool.self, forKey: key) ?? false
    }

    /// Decodes a string, yielding the empty string when it is absent.
    func decodeString(forKey key: Key) throws -> String {
        try decodeIfPresent(String.self, forKey: key) ?? ""
    }

    /// Decodes an integer, yielding 0 when it is absent.
    func decodeInt(forKey key: Key) throws -> Int {
        try decodeIfPresent(Int.self, forKey: key) ?? 0
    }

    /// Decodes an enum, yielding `.unspecified` when it is absent or unrecognized.
    func decodeProtoEnum<E: ProtoEnum>(_ type: E.Type = E.self, forKey key: Key) throws -> E {
        try decodeIfPresent(E.self, forKey: key) ?? .unspecified
    }

    /// Decodes a required identifier, yielding an empty one when it is absent — which is how a
    /// missing required ID survives decoding instead of throwing.
    func decodeID<I: A2AIdentifier>(_ type: I.Type = I.self, forKey key: Key) throws -> I {
        try decodeIfPresent(I.self, forKey: key) ?? I("")
    }

    /// Decodes an optional identifier, treating both an absent field and an empty string as `nil`.
    func decodeOptionalID<I: A2AIdentifier>(_ type: I.Type = I.self, forKey key: Key) throws -> I? {
        guard let id = try decodeIfPresent(I.self, forKey: key), !id.rawValue.isEmpty else { return nil }
        return id
    }
}

extension KeyedEncodingContainer {
    /// Writes an array only when it has elements.
    mutating func encodeIfNonEmpty<T: Encodable>(_ value: [T], forKey key: Key) throws {
        if !value.isEmpty { try encode(value, forKey: key) }
    }

    /// Writes a map only when it has entries.
    mutating func encodeIfNonEmpty<V: Encodable>(_ value: [String: V], forKey key: Key) throws {
        if !value.isEmpty { try encode(value, forKey: key) }
    }

    /// Writes a string only when it is non-empty.
    mutating func encodeIfNonEmpty(_ value: String, forKey key: Key) throws {
        if !value.isEmpty { try encode(value, forKey: key) }
    }

    /// Writes an identifier only when it is non-empty.
    mutating func encodeIfNonEmpty<I: A2AIdentifier>(_ value: I, forKey key: Key) throws {
        if !value.rawValue.isEmpty { try encode(value, forKey: key) }
    }

    /// Writes an integer only when it is not zero.
    mutating func encodeIfNonZero(_ value: Int, forKey key: Key) throws {
        if value != 0 { try encode(value, forKey: key) }
    }

    /// Writes a bool only when it is `true`.
    mutating func encodeIfTrue(_ value: Bool, forKey key: Key) throws {
        if value { try encode(value, forKey: key) }
    }

    /// Writes an enum only when it is not `.unspecified`.
    mutating func encode<E: ProtoEnum>(proto value: E, forKey key: Key) throws {
        if value != .unspecified { try encode(value, forKey: key) }
    }
}
