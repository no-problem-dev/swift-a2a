import Foundation

/// The coders every A2A payload must go through.
///
/// A stock `JSONCoder` writes dates as numbers, which produces JSON no A2A peer can read. These
/// factories return coders configured for the RFC 3339 strings the specification requires. Base64
/// for `bytes` needs no configuration — Foundation's default already matches.
///
/// Each call builds a fresh coder; hold on to one if you are encoding in a loop.
public enum A2AJSON {
    /// A decoder that reads timestamps as RFC 3339, with or without fractional seconds.
    public static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            guard let date = RFC3339.date(from: string) else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Invalid RFC 3339 timestamp: \(string)"
                )
            }
            return date
        }
        return decoder
    }

    /// An encoder that writes timestamps as RFC 3339 UTC with millisecond precision.
    public static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(RFC3339.string(from: date))
        }
        return encoder
    }
}
