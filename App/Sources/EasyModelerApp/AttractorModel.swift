import EasyModelerKit
import Observation

/// The Lorenz playground's observable state: the three system parameters and the
/// trajectory (or two, for the butterfly-effect twin) they produce. The Kit's
/// `LorenzModel` is the numerics; this is the view-facing knobs and the sampled
/// path the 3D stage draws.
///
/// Integration is heavier than predator–prey (a few thousand steps for a filled
/// attractor), but still runs inline on each change with a relaxed tolerance so
/// the stage tracks a slider drag. If the device gate shows jank, decimate the
/// path while dragging — see `docs/PLAN.md`.
@Observable
final class AttractorModel {
  var sigma = 10.0
  var rho = 28.0
  var beta = 8.0 / 3.0

  /// When on, a second path starts a hair away from the first — the two diverge
  /// past the Lyapunov time, which is the butterfly-effect lesson.
  private(set) var showTwin = false

  private(set) var samples: [AttractorSample] = []
  private(set) var twinSamples: [AttractorSample] = []

  /// Bumped on each discrete jump (Reset / preset / twin toggle) so the view can
  /// fire one haptic tick — never on a continuous slider drag.
  private(set) var discreteEventCount = 0

  /// Bumped on every re-integration; the 3D stage rebuilds its geometry only
  /// when this changes, and just moves the marker otherwise.
  private(set) var revision = 0

  /// The time span the trajectory covers (samples run from t = 0 to `horizon`).
  let horizon = 30.0
  private let sampleCount = 2000
  private let start = [0.0, 1.0, 1.05]
  private let twinOffset = 1e-3

  init() {
    recompute()
  }

  /// Re-integrate the current parameters into a fresh trajectory (and its twin
  /// when shown). A relaxed tolerance keeps the interactive redraw quick while
  /// the attractor stays smooth.
  func recompute() {
    samples = integrate(from: start)
    twinSamples =
      showTwin ? integrate(from: [start[0] + twinOffset, start[1], start[2]]) : []
    revision += 1
  }

  private func integrate(from initial: [Double]) -> [AttractorSample] {
    let model = LorenzModel(sigma: sigma, rho: rho, beta: beta)
    let control = StepControl(relative: 1e-6, absolute: 1e-8)
    let dt = horizon / Double(sampleCount)
    let trajectory = ODESolver.integrate(
      system: model.system, initial: initial, step: dt, count: sampleCount,
      control: control)

    // The engine excludes the initial state; prepend it so the path starts where
    // the run begins.
    var built = [AttractorSample(t: 0, x: initial[0], y: initial[1], z: initial[2])]
    for (index, state) in trajectory.enumerated() {
      built.append(
        AttractorSample(
          t: Double(index + 1) * dt, x: state[0], y: state[1], z: state[2]))
    }
    return built
  }

  /// A one-line, plain-language read of the current run. With the twin shown it
  /// names the butterfly effect; otherwise it splits calm settling from chaos at
  /// the Hopf threshold (`rho ≈ 24.74` for the classic `sigma`/`beta`).
  var insight: String {
    if showTwin {
      return "Two nearly identical starts — watch them drift apart. That's the butterfly effect."
    }
    if rho < 24.74 {
      return "Calm: the trail spirals in and settles toward a steady point."
    }
    return "Chaos: the path loops forever and never quite repeats — the two wings of the butterfly."
  }

  /// Turn the twin path on or off (a discrete jump) and re-integrate.
  func setTwin(_ on: Bool) {
    showTwin = on
    discreteEventCount += 1
    recompute()
  }

  /// Adopt a preset's three parameters and re-integrate (a discrete jump).
  func apply(_ preset: AttractorPreset) {
    sigma = preset.sigma
    rho = preset.rho
    beta = preset.beta
    discreteEventCount += 1
    recompute()
  }

  /// Restore the classic butterfly and drop the twin.
  func reset() {
    showTwin = false
    apply(.classicButterfly)
  }
}
