import EasyModelerKit
import Foundation
import Observation

/// The estuary playground's observable state: an **open** benthos–nutrient system
/// grounded in the Benthic Ecology Model. You feed it (the food slider) and set
/// the starting populations; the seasons (temperature and salinity, two sine
/// waves over a year) run underneath. Because nitrogen flows in and is buried
/// out, it never settles — the benthos blooms in spring and crashes in the
/// summer heat and salt.
///
/// Integration runs inline on every change over the 365-day year (a few hundred
/// adaptive steps) with a relaxed tolerance, so the chart tracks the sliders.
@Observable
final class BenthosModel {
  /// Continuous daily nutrient input to the water column — the nutrient slider.
  /// It flows in every day (not a one-off pulse), and high-mortality species need
  /// a lot of it to hold on.
  var nutrientInput = 3.0
  /// Benthic biomass at day 0.
  var startingLife = 1.0
  /// Nutrient in the water column at day 0.
  var startingNutrient = 5.0

  /// Baseline salinity (PSU). The slider shifts the whole seasonal wave up or
  /// down bodily — the shape stays, the level moves — which slides conditions
  /// toward or away from a species' optimum.
  var salinityMean = 18.0
  /// Baseline temperature (°C), shifted the same way.
  var temperatureMean = 21.0

  /// Which calibrated species is in the tank (its optima shift the bloom).
  private(set) var species: BenthosPreset = .streblospio

  /// The selected species' trajectory, including day 0.
  private(set) var samples: [BenthosSample] = []

  /// Every species' trajectory under the current settings — for the combined
  /// three-species comparison view.
  private(set) var allTraces: [(preset: BenthosPreset, samples: [BenthosSample])] = []

  /// Bumped on each discrete jump (species / Reset) for a single haptic tick.
  private(set) var discreteEventCount = 0

  /// The time span the run covers (days 0…horizon).
  let horizon = 365.0
  private let dayCount = 365

  init() {
    recompute()
  }

  /// Two sine waves over the year: temperature and salinity, both peaking in
  /// summer (the marsh runs warmer and saltier together), winter at the trough.
  private func seasonalForcing() -> [(temperature: Double, salinity: Double)] {
    (0..<dayCount).map { day in
      let season = -cos(2 * Double.pi * Double(day) / Double(dayCount))
      return (
        temperature: max(0, temperatureMean + 9 * season),
        salinity: max(0, salinityMean + 8 * season)
      )
    }
  }

  /// Re-integrate every species under the current settings. The selected one
  /// drives the Life/Seasons views; all three feed the comparison view. Relaxed
  /// tolerance keeps the redraw instant while the curves stay smooth.
  func recompute() {
    let forcing = seasonalForcing()
    allTraces = BenthosPreset.gallery.map { preset in
      (preset, integrate(preset: preset, forcing: forcing))
    }
    samples = allTraces.first { $0.preset == species }?.samples ?? []
  }

  /// Integrate one species over the seasonal year with the current nutrient input
  /// and starting state, prepending day 0 (the engine excludes the initial state).
  private func integrate(
    preset: BenthosPreset, forcing: [(temperature: Double, salinity: Double)]
  ) -> [BenthosSample] {
    var model = preset.model
    model.foodInput = nutrientInput
    let control = StepControl(relative: 1e-7, absolute: 1e-9)
    let trajectory = ODESolver.integrateForced(
      systemFor: { model.system(temperature: $0.temperature, salinity: $0.salinity) },
      initial: [startingNutrient, startingLife], forcings: forcing, step: 1.0, control: control)

    guard let first = forcing.first else { return [] }
    var built = [
      BenthosSample(
        day: 0, nutrient: startingNutrient, benthos: startingLife,
        temperature: first.temperature, salinity: first.salinity)
    ]
    for (index, state) in trajectory.enumerated() {
      let day = index + 1
      let conditions = forcing[min(day, dayCount - 1)]
      built.append(
        BenthosSample(
          day: Double(day), nutrient: state[0], benthos: state[1],
          temperature: conditions.temperature, salinity: conditions.salinity))
    }
    return built
  }

  /// The sampled state nearest day `t` (clamped) — the point the playhead rides.
  func sample(at t: Double) -> BenthosSample {
    guard let first = samples.first, let last = samples.last else {
      return BenthosSample(
        day: 0, nutrient: startingNutrient, benthos: startingLife, temperature: 0, salinity: 0)
    }
    let clamped = min(max(t, 0), horizon)
    let index = Int((clamped / horizon) * Double(samples.count - 1) + 0.5)
    if index <= 0 { return first }
    if index >= samples.count - 1 { return last }
    return samples[index]
  }

  /// A one-line, plain-language read of the current run — the bloom, the summer
  /// crash, or a population that never really gets going.
  var insight: String {
    guard samples.count > 2 else { return "" }
    let life = samples.map(\.benthos)
    guard let peak = life.max(), let low = life.min() else { return "" }
    if peak < 0.5 {
      return "Barely any life takes hold — the food or the seasons don't suit this species."
    }
    if low < 0.2 * peak {
      return "Life blooms when conditions are right, then crashes in the summer heat and salt."
    }
    return "The population rides the seasons — swelling and thinning as the water warms and salts."
  }

  /// Adopt a species (a discrete jump) and re-integrate.
  func apply(_ preset: BenthosPreset) {
    species = preset
    discreteEventCount += 1
    recompute()
  }

  /// Restore the default: the bristle worm, a modest nutrient input, a small start.
  func reset() {
    nutrientInput = 3
    startingLife = 1
    startingNutrient = 5
    salinityMean = 18
    temperatureMean = 21
    species = .streblospio
    discreteEventCount += 1
    recompute()
  }
}
