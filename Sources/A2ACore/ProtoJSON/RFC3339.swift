import Foundation

/// Converts between `Date` and the RFC 3339 strings A2A uses for timestamps (spec §5.6.1).
///
/// Asymmetric on purpose: parsing accepts fractional seconds or not, while writing always emits
/// them. A value therefore does not round-trip byte-for-byte through a peer that omits them.
public enum RFC3339 {
    /// Parses an RFC 3339 timestamp, with or without fractional seconds.
    ///
    /// - Returns: The instant, or `nil` if the string is not RFC 3339. Offsets other than `Z` are
    ///   accepted and normalized.
    public static func date(from string: String) -> Date? {
        let withFractional = ISO8601DateFormatter()
        withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFractional.date(from: string) { return date }

        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: string)
    }

    /// Formats an instant as `YYYY-MM-DDTHH:mm:ss.sssZ` — always UTC, always with milliseconds.
    ///
    /// The fractional part is unconditional, so a peer that only parses whole seconds will reject
    /// the result.
    public static func string(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}
