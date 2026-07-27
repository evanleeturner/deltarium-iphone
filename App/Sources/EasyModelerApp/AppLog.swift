import OSLog

/// Minimal lifecycle logging. The full LOGLINE grammar (the app owns its log
/// line) is a P4 concern; this is just enough to see launches in the device
/// console.
enum AppLog {
  static let lifecycle = Logger(
    subsystem: "com.evanleeturner.easymodeler", category: "lifecycle")
}
