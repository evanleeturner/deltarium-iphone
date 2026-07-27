import EasyModelerKit
import Observation

/// The radioactivity playground's observable state: which source, how concentrated,
/// and how far away — and the decay curve they produce. The Kit's `DecayChainModel`
/// and `RadiationSource` are the numerics; this is the view-facing knobs and the
/// sampled activity the chart draws.
///
/// Each of the source's chains is integrated and its activity normalized to its own
/// start, so every isotope contributes equally at t = 0 and all the timescales show
/// on one linear axis (the iodine crashing in weeks, the caesium and strontium over
/// centuries). Distance dims the whole curve by an inverse-square-style dose falloff;
/// concentration scales it up. Carbon-14 (natural dating) uses neither.
@Observable
final class RadioactivityModel {
  /// Index into `RadiationSource.all` — 0 Carbon-14, 1 Accident, 2 H-bomb.
  private(set) var sourceIndex = 1

  /// Distance from the source, in miles (Accident and H-bomb only).
  var distanceMiles = 0.0
  /// Relative concentration of the release (Accident and H-bomb only).
  var concentration = 1.0

  private(set) var samples: [RadioactivitySample] = []
  private(set) var discreteEventCount = 0
  private(set) var revision = 0

  private let sampleCount = 800
  /// The background level a run is "safe" once it falls below, in percent.
  let safeLevel = 1.0
  private let distanceScaleMiles = 20.0

  var source: RadiationSource { RadiationSource.all[sourceIndex] }
  var horizon: Double { source.horizonYears }

  /// Carbon-14 is natural dating, not an environmental release — it has no distance
  /// or concentration knobs.
  var usesDoseControls: Bool { sourceIndex != 0 }

  /// Carbon-14 *is* natural background (cosmic-ray made, the basis of radiocarbon
  /// dating), not a release that clears to a safe level — so it shows its half-life
  /// as a dating clock, and no "safe background" line.
  var isNaturalBackground: Bool { sourceIndex == 0 }

  /// The parent half-life to mark on the chart for the natural-dating case (else nil).
  var datingHalfLife: Double? {
    isNaturalBackground ? source.chains.first?.members.first?.halfLifeYears : nil
  }

  init() {
    recompute()
  }

  /// Re-integrate the selected source's chains into a fresh activity curve.
  func recompute() {
    let source = self.source
    let dt = source.horizonYears / Double(sampleCount)
    let control = StepControl(relative: 1e-8, absolute: 1e-12)

    // Each chain's activity over time, normalized to its own initial activity.
    let chainCurves = source.chains.map { chain -> [Double] in
      let trajectory = ODESolver.integrate(
        system: chain.model.system, initial: chain.initialAmounts, step: dt,
        count: sampleCount, control: control)
      let full = [chain.initialAmounts] + trajectory
      let initialActivity = chain.activity(chain.initialAmounts)
      return full.map { chain.activity($0) / initialActivity }
    }

    let chainShare = 100.0 / Double(source.chains.count)
    let dose = usesDoseControls ? concentration * distanceFactor : 1.0

    samples = (0...sampleCount).map { index in
      let total = chainCurves.reduce(0.0) { $0 + $1[index] }
      return RadioactivitySample(t: Double(index) * dt, level: dose * chainShare * total)
    }
    revision += 1
  }

  /// Inverse-square-style dose falloff, finite at zero distance.
  private var distanceFactor: Double {
    let ratio = distanceMiles / distanceScaleMiles
    return 1.0 / (1.0 + ratio * ratio)
  }

  /// The activity level at an arbitrary time (linear interpolation), for the playhead.
  func sample(at time: Double) -> RadioactivitySample {
    guard samples.count > 1 else { return samples.first ?? RadioactivitySample(t: 0, level: 0) }
    let dt = horizon / Double(sampleCount)
    let position = min(max(time / dt, 0), Double(samples.count - 1))
    let index = min(Int(position), samples.count - 2)
    let blend = position - Double(index)
    let a = samples[index]
    let b = samples[index + 1]
    return RadioactivitySample(
      t: time, level: a.level + (b.level - a.level) * blend)
  }

  /// The isotopes released by the current source, for the caption.
  var sourceDescription: String {
    switch sourceIndex {
    case 0: "Carbon-14 → nitrogen. Natural — the clock behind radiocarbon dating."
    case 2: "Plutonium-239 decays into a uranium series — radioactive for ages."
    default: "Iodine-131, Caesium-137, Strontium-90 — reactor fallout."
    }
  }

  /// A one-line, plain-language read: the dating half-life for carbon, else how long
  /// until the level falls below "safe".
  var insight: String {
    if isNaturalBackground {
      return
        "Half the carbon-14 is left after 5,730 years — the steady clock behind radiocarbon dating."
    }
    guard let start = samples.first, start.level > safeLevel else {
      return "Already below the safe line — little radioactivity reaches you here."
    }
    guard let crossing = samples.first(where: { $0.level <= safeLevel }) else {
      return "It never fully clears — a faint trace stays radioactive far beyond the chart."
    }
    return "Falls to a safe background after about \(formattedYears(crossing.t))."
  }

  private func formattedYears(_ years: Double) -> String {
    if years < 1 { return "a few months" }
    if years < 1000 { return "\(Int(years.rounded())) years" }
    let thousands = years / 1000
    return "\(Int(thousands.rounded())),000 years"
  }

  /// Switch source (a discrete jump), resetting the dose knobs, and re-integrate.
  func selectSource(_ index: Int) {
    sourceIndex = index
    distanceMiles = 0
    concentration = 1
    discreteEventCount += 1
    recompute()
  }

  /// Restore the default view of the current source.
  func reset() {
    distanceMiles = 0
    concentration = 1
    discreteEventCount += 1
    recompute()
  }
}
