import Foundation

/// Loads the tier-2 fidelity fixtures bundled with the test target.
///
/// The CSVs under `Fixtures/` are the frozen Python `port_reference` outputs
/// (`ex1`/`ex2`/`ex3`) and the `food` forcing series, emitted full-precision by
/// `tools/export_fixtures.py`. They are the *only* source of reference numbers
/// for the fidelity fences — there are no invented oracles.
enum Fixture {
  enum LoadError: Error {
    case resourceMissing(String)
    case notANumber(fixture: String, field: String)
  }

  private static func url(_ name: String) throws -> URL {
    guard
      let url = Bundle.module.url(
        forResource: name, withExtension: "csv", subdirectory: "Fixtures")
    else {
      throw LoadError.resourceMissing(name)
    }
    return url
  }

  private static func number(_ field: Substring, in fixture: String) throws -> Double {
    guard let value = Double(field) else {
      throw LoadError.notANumber(fixture: fixture, field: String(field))
    }
    return value
  }

  /// A trajectory fixture: one row per line, components comma-separated. Splits
  /// on any newline (a CRLF is one grapheme, so `split(separator: "\n")` would
  /// miss it), skipping blank lines.
  static func matrix(_ name: String) throws -> [[Double]] {
    let text = try String(contentsOf: url(name), encoding: .utf8)
    return try text.split(whereSeparator: { $0.isNewline }).map { line in
      try line.split(separator: ",").map { try number($0, in: name) }
    }
  }

  /// A scalar-series fixture: one value per line.
  static func vector(_ name: String) throws -> [Double] {
    let text = try String(contentsOf: url(name), encoding: .utf8)
    return try text.split(whereSeparator: { $0.isNewline }).map { try number($0, in: name) }
  }
}
