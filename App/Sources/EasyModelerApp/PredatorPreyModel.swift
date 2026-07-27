import EasyModelerKit
import Observation

/// The playground's observable state: the six Lotka-Volterra knobs and the
/// trajectory they produce. Lives on the main actor (the UI is its only
/// toucher); integration is cheap enough — a few hundred adaptive steps — to
/// run inline on every slider tick, so the chart tracks the finger with no
/// perceptible lag. Heavier models (Lorenz) will move this off the main actor.
@Observable
final class PredatorPreyModel {
  /// Prey birth rate (A).
  var preyGrowth = 1.0
  /// Predation rate on prey (B).
  var predation = 1.0
  /// Predator death rate (C).
  var predatorDeath = 1.0
  /// Predator growth per predation (D).
  var predatorGrowth = 1.0
  /// Prey population at t = 0.
  var startingPrey = 3.0
  /// Predator population at t = 0.
  var startingPredators = 2.0

  /// The current trajectory, including the initial state at t = 0.
  private(set) var samples: [PopulationSample] = []

  /// Bumped on each discrete jump (Reset / preset) so the view can fire one
  /// haptic tick and animate — never on a continuous slider drag.
  private(set) var discreteEventCount = 0

  /// The time span the trajectory covers (samples run from t = 0 to `horizon`).
  let horizon = 20.0
  private let sampleCount = 400

  init() {
    recompute()
  }

  /// The sampled state nearest time `t` (clamped to `[0, horizon]`) — the point
  /// the playhead rides for the time animation.
  func sample(at t: Double) -> PopulationSample {
    guard let first = samples.first, let last = samples.last else {
      return PopulationSample(t: 0, prey: startingPrey, predator: startingPredators)
    }
    let clamped = min(max(t, 0), horizon)
    let index = Int((clamped / horizon) * Double(samples.count - 1) + 0.5)
    if index <= 0 { return first }
    if index >= samples.count - 1 { return last }
    return samples[index]
  }

  /// Re-integrate the current parameters into a fresh trajectory. A relaxed
  /// tolerance (vs. the tight fidelity default) keeps the interactive redraw
  /// instant while the curve stays smooth.
  func recompute() {
    let model = LotkaVolterraModel(
      a: preyGrowth, b: predation, c: predatorDeath, d: predatorGrowth)
    let initial = [startingPrey, startingPredators]
    let control = StepControl(relative: 1e-7, absolute: 1e-9)
    let dt = horizon / Double(sampleCount)
    let trajectory = ODESolver.integrate(
      system: model.system, initial: initial, step: dt, count: sampleCount,
      control: control)

    // The engine excludes the initial state; prepend it so the curve starts at
    // t = 0 with the populations the sliders show.
    var built = [PopulationSample(t: 0, prey: initial[0], predator: initial[1])]
    for (index, state) in trajectory.enumerated() {
      built.append(
        PopulationSample(t: Double(index + 1) * dt, prey: state[0], predator: state[1]))
    }
    samples = built
  }

  /// A one-line, plain-language read of what the current run does — the boom,
  /// the chase, or a near-crash. Honest to the model (pure LV never fully
  /// extinguishes a species, so it says "nearly").
  var insight: String {
    guard samples.count > 2 else { return "" }
    let preyValues = samples.map(\.prey)
    let predatorValues = samples.map(\.predator)
    guard let preyMax = preyValues.max(), let predatorMax = predatorValues.max(),
      let preyMin = preyValues.min(), let predatorMin = predatorValues.min()
    else {
      return ""
    }
    if predatorMin < 0.05 * predatorMax {
      return "The predators run low on food and nearly fade away."
    }
    if preyMin < 0.05 * preyMax {
      return "The prey get eaten down to almost nothing, then bounce back."
    }
    return "Prey boom, predators follow — the two chase each other round and round."
  }

  /// Adopt a preset's six parameters and re-integrate (a discrete jump).
  func apply(_ preset: Preset) {
    preyGrowth = preset.preyGrowth
    predation = preset.predation
    predatorDeath = preset.predatorDeath
    predatorGrowth = preset.predatorGrowth
    startingPrey = preset.startingPrey
    startingPredators = preset.startingPredators
    discreteEventCount += 1
    recompute()
  }

  /// Restore the canonical closed-orbit demo (A=B=C=D=1, 3 prey, 2 predators).
  func reset() {
    apply(Preset.gallery[0])
  }
}
