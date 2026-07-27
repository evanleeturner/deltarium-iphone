import SwiftUI

/// The shell entry point. All numerics live in `EasyModelerKit` (pure Swift,
/// Linux-buildable); this target is the thin, device-only SwiftUI shell. The
/// landing experience is the home model picker, which branches to the
/// predator–prey playground (the front door) and the Lorenz butterfly.
@main
struct EasyModelerApp: App {
  init() {
    AppLog.lifecycle.info("Deltarium launched")
  }

  var body: some Scene {
    WindowGroup {
      HomeScreen()
    }
  }
}
