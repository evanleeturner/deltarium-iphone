import EasyModelerKit
import Observation

/// The three-body playground's observable state: the chosen arrangement, how far
/// the first star's mass is pushed off balance, and the sampled trails the 3D
/// stage draws (plus a ghost twin for the sensitivity beat). The Kit's
/// `ThreeBodyModel` is the numerics; this is the view-facing knobs.
///
/// Integration is heavier than the planar models — three bodies, ~1200 steps for
/// smooth trails — but still runs inline on each change with a relaxed tolerance so
/// the stage tracks a slider drag. If the device gate shows jank, decimate the
/// trails while dragging — see `docs/PLAN.md`.
@Observable
final class OrbitsModel {
  /// How much heavier the first star is than the arrangement sets it — the
  /// headline knob. `1` is the arrangement as designed (the balanced figure-8);
  /// pushing it up breaks the symmetry and order slides into chaos.
  var heaviness = 1.0

  private(set) var preset = OrbitPreset.figureEight

  /// When on, a second run starts a hair from the first. On the stable figure-8 it
  /// stays locked to the original; in the chaotic arrangements it peels away — the
  /// butterfly-effect beat, either way a lesson.
  private(set) var showTwin = false

  private(set) var samples: [OrbitSample] = []
  private(set) var twinSamples: [OrbitSample] = []

  /// Bumped on each discrete jump (Reset / preset / twin toggle) so the view can
  /// fire one haptic tick — never on a continuous slider drag.
  private(set) var discreteEventCount = 0

  /// Bumped on every re-integration; the 3D stage rebuilds its geometry only when
  /// this changes, and just moves the markers otherwise.
  private(set) var revision = 0

  /// The time span the trails cover — two figure-8 periods (T ≈ 6.3259), enough
  /// for two full loops of the dance and a good stretch of the chaotic scrambles.
  let horizon = 12.65
  private let sampleCount = 1200
  /// The nudge applied to the ghost twin's first star (in position).
  private let twinOffset = 1e-2

  init() {
    recompute()
  }

  /// Re-integrate the current arrangement into fresh trails (and the twin when
  /// shown). A relaxed tolerance keeps the interactive redraw quick.
  func recompute() {
    samples = integrate(perturbed: false)
    twinSamples = showTwin ? integrate(perturbed: true) : []
    revision += 1
  }

  private func integrate(perturbed: Bool) -> [OrbitSample] {
    let base = preset.configuration
    let model = ThreeBodyModel(
      masses: (base.masses.0 * heaviness, base.masses.1, base.masses.2), g: 1,
      softening: base.softening)

    var initial = base.initialState
    if perturbed {
      initial[0] += twinOffset  // nudge the first star's x — the butterfly seed
    }

    let control = StepControl(relative: 1e-6, absolute: 1e-8)
    let dt = horizon / Double(sampleCount)
    let trajectory = ODESolver.integrate(
      system: model.system, initial: initial, step: dt, count: sampleCount, control: control)

    // The engine excludes the initial state; prepend it so the trail starts where
    // the run begins.
    var built = [OrbitSample(t: 0, state: initial)]
    for (index, state) in trajectory.enumerated() {
      built.append(OrbitSample(t: Double(index + 1) * dt, state: state))
    }
    return built
  }

  /// A one-line, plain-language read of the current run.
  var insight: String {
    if showTwin {
      return "A second run starts a hair away — watch it stay locked, or drift off."
    }
    switch preset.name {
    case "Pythagoras":
      return "Released from rest, the stars fall together and fling one away — pure chaos."
    case "3D tangle":
      return "Launched out of the plane, three stars tumble through space and never repeat."
    default:
      if heaviness < 1.15 {
        return "Three equal stars trace one perfect figure-8 — a rare island of order."
      }
      return "One heavy star breaks the balance, and the tidy 8 unravels into chaos."
    }
  }

  /// Turn the ghost twin on or off (a discrete jump) and re-integrate.
  func setTwin(_ on: Bool) {
    showTwin = on
    discreteEventCount += 1
    recompute()
  }

  /// Adopt an arrangement, rebalanced to its designed masses (a discrete jump).
  func apply(_ preset: OrbitPreset) {
    self.preset = preset
    heaviness = 1
    discreteEventCount += 1
    recompute()
  }

  /// Restore the balanced figure-8 and drop the twin.
  func reset() {
    showTwin = false
    apply(.figureEight)
  }
}
