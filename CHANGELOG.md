# Changelog

## [Unreleased]

## [0.8.0] - 2026-08-11

### Changed

- Builds and tests on Linux. `URLSession.AsyncBytes` does not exist in FoundationNetworking, and
  server-sent events are the point of the streaming binding, so `HTTPClient.stream` is rebuilt on
  `URLSessionDataDelegate` — one code path on both platforms, not a `#if` fork. The response head
  still resumes before the body is consumed, so the status remains checkable.


## [0.7.2] - 2026-08-11

### Changed

- Raised the swift-structured-data pin to 3.0.0. That release makes the YAML parser reject
  constructs it does not model instead of silently dropping them; nothing in this package's own
  API changes.


## [0.7.1] - 2026-07-30

See [GitHub Releases](../../releases) for changes up to and including this version.
