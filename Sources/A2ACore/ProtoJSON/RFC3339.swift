import Foundation

/// A2A の `google.protobuf.Timestamp` 表現（仕様 §5.6.1）。
///
/// ISO 8601 / RFC 3339 の UTC 文字列（末尾 `Z`）として表現します。出力はミリ秒精度、
/// 入力は小数秒あり／なしの双方を受理します。
public enum RFC3339 {
    /// RFC 3339 文字列を `Date` に変換します。小数秒の有無を問わず受理します。
    public static func date(from string: String) -> Date? {
        let withFractional = ISO8601DateFormatter()
        withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFractional.date(from: string) { return date }

        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: string)
    }

    /// `Date` をミリ秒精度・UTC の RFC 3339 文字列（`YYYY-MM-DDTHH:mm:ss.sssZ`）に変換します。
    public static func string(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}
