import Foundation

/// Converts between `Date` and the RFC 3339 strings A2A uses for timestamps (spec §5.6.1).
///
/// This is the one place the package decides what a timestamp looks like. Every peer of it — the
/// JSON body coder, the REST client's query parameters, the REST server's query parsing — goes
/// through here rather than configuring a formatter of its own, so no two sides can drift into
/// writing one shape and reading another.
///
/// The shape written is always the full one, with milliseconds and in UTC. Reading also accepts the
/// fractional part being absent, since a peer that omits it is still RFC 3339.
public enum RFC3339 {
    /// The representation this package writes, and the one it tries first when reading.
    private static let canonical: ISO8601DateFormatter.Options = [.withInternetDateTime, .withFractionalSeconds]

    /// Parses an RFC 3339 timestamp, with or without fractional seconds.
    ///
    /// - Returns: The instant, or `nil` if the string is not RFC 3339. Offsets other than `Z` are
    ///   accepted and normalized.
    public static func date(from string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = canonical
        if let date = formatter.date(from: string) { return date }

        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }

    /// Formats an instant as `YYYY-MM-DDTHH:mm:ss.sssZ` — always UTC, always with milliseconds.
    public static func string(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = canonical
        return formatter.string(from: date)
    }
}
