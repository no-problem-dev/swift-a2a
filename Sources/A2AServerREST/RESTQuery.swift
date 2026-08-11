import A2ACore
import A2AServer
import Foundation

/// Reads typed values out of a request's query, keeping absence and garbage apart.
///
/// A parameter that is not there reads as `nil`. A parameter that is there but will not parse
/// throws — it never reads as `nil`. Collapsing the two is what turns a filter the server could not
/// understand into a filter the caller appears not to have asked for: the response comes back 200
/// with every task in it, and nothing in it says the request was rejected. An error the caller can
/// see is the smaller failure.
struct RESTQuery {
    private let values: [String: String]

    init(_ values: [String: String]) {
        self.values = values
    }

    /// A parameter taken as written. Every string is a valid one, so this cannot fail.
    func string(_ name: String) -> String? {
        values[name]
    }

    func int(_ name: String) throws -> Int? {
        try parsed(name, Int.init)
    }

    /// `true` or `false`, spelled as `Bool` writes itself — which is what this package's client
    /// sends. Nothing else is a boolean.
    func bool(_ name: String) throws -> Bool? {
        try parsed(name) { raw in
            switch raw {
            case "true": true
            case "false": false
            default: nil
            }
        }
    }

    /// An RFC 3339 timestamp, read by the same ``RFC3339`` the client writes with.
    func date(_ name: String) throws -> Date? {
        try parsed(name, RFC3339.date(from:))
    }

    /// A task state by its protocol enum name, such as `TASK_STATE_WORKING`.
    func taskState(_ name: String) throws -> TaskState? {
        try parsed(name, TaskState.init(rawValue:))
    }

    private func parsed<T>(_ name: String, _ convert: (String) -> T?) throws -> T? {
        guard let raw = values[name] else { return nil }
        guard let value = convert(raw) else {
            throw A2AServerError.invalidParams("Invalid value for \(name): \(raw)")
        }
        return value
    }
}
