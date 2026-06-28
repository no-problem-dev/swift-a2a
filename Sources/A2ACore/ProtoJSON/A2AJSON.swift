import Foundation

/// A2A の ProtoJSON 表現を読み書きするための正準コーダ。
///
/// A2A データモデルの JSON は通常の `JSONEncoder`/`JSONDecoder` 既定設定では
/// タイムスタンプを正しく扱えない（既定の日付戦略は数値）。本ファクトリは
/// 仕様 §5.6.1 の RFC 3339 文字列でタイムスタンプを符号化／復号する設定済みコーダを返す。
/// `bytes`（Base64）は Foundation 既定の Base64 戦略でそのまま扱える。
public enum A2AJSON {
    /// A2A JSON を復号する `JSONDecoder`。
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

    /// A2A JSON を符号化する `JSONEncoder`。
    public static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(RFC3339.string(from: date))
        }
        return encoder
    }
}
