import EasyModelerKit
import Observation

/// The Lagrange playground's observable state: a shared launch delta-v and the
/// five satellite trails it produces — one satellite dropped at each of L1–L5. The
/// Kit's `RestrictedThreeBodyModel` is the numerics; this is the view-facing kick
/// and the sampled paths the 3D stage draws.
///
/// Each satellite is its own CR3BP integration from its Lagrange point with the
/// shared kick, run inline on each change with a relaxed tolerance so the stage
/// tracks a slider drag. Five short integrations are cheap; if the device gate
/// shows jank on the escaping satellites' close approaches, relax the tolerance or
/// decimate — see `docs/PLAN.md`.
@Observable
final class LagrangeModel {
  /// The launch delta-v, shared by all five satellites, in rotating-frame
  /// components. `x` points from the barycenter toward the Moon, `y` along the
  /// orbit, `z` out of the plane. Zero leaves every satellite sitting still at its
  /// point; a kick reveals which points hold and which let go.
  var towardMoon = 0.0
  var alongOrbit = 0.02
  var outOfPlane = 0.005

  private(set) var samples: [LagrangeSample] = []

  /// Bumped on each discrete jump (Reset / preset) so the view can fire one haptic
  /// tick — never on a continuous slider drag.
  private(set) var discreteEventCount = 0

  /// Bumped on every re-integration; the 3D stage rebuilds its geometry only when
  /// this changes, and just moves the markers otherwise.
  private(set) var revision = 0

  /// The time span the trails cover — two synodic periods of the Earth–Moon system.
  let horizon = EarthMoonSystem.period * 2
  private let sampleCount = 1200

  init() {
    recompute()
  }

  /// Re-integrate all five satellites into fresh trails.
  func recompute() {
    let deltaV = [towardMoon, alongOrbit, outOfPlane]
    let model = RestrictedThreeBodyModel()
    let control = StepControl(relative: 1e-7, absolute: 1e-9)
    let dt = horizon / Double(sampleCount)

    // The engine excludes the initial state; prepend it so each trail starts at its
    // Lagrange point.
    let trajectories = EarthMoonSystem.lagrangePoints.map { point -> [[Double]] in
      let initial = EarthMoonSystem.launchState(at: point, deltaV: deltaV)
      let trajectory = ODESolver.integrate(
        system: model.system, initial: initial, step: dt, count: sampleCount, control: control)
      return [initial] + trajectory
    }

    samples = (0...sampleCount).map { index in
      let positions = trajectories.map { trajectory in
        let state = trajectory[index]
        return SIMD3<Float>(Float(state[0]), Float(state[1]), Float(state[2]))
      }
      return LagrangeSample(t: Double(index) * dt, positions: positions)
    }
    revision += 1
  }

  /// A one-line, plain-language read of the current run.
  var insight: String {
    let speed = (towardMoon * towardMoon + alongOrbit * alongOrbit + outOfPlane * outOfPlane)
      .squareRoot()
    if speed < 1e-6 {
      return "No kick: every satellite sits perfectly still — all five points are in balance."
    }
    return
      "Give them a kick and watch: L4 and L5 hold their ground, while L1, L2, and L3 drift off."
  }

  /// Adopt a launch kick (a discrete jump) and re-integrate.
  func applyKick(towardMoon x: Double, alongOrbit y: Double, outOfPlane z: Double) {
    towardMoon = x
    alongOrbit = y
    outOfPlane = z
    discreteEventCount += 1
    recompute()
  }

  /// Restore the default gentle nudge.
  func reset() {
    applyKick(towardMoon: 0, alongOrbit: 0.02, outOfPlane: 0.005)
  }
}
