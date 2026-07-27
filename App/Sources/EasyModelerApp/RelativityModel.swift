import EasyModelerKit
import Foundation
import Observation

/// The relativistic-journey playground's observable state: pick a destination and
/// a g-force, and it integrates the flip-and-burn over the ship's own clock —
/// how far, how fast, how much ship time versus Earth time — and works out the
/// astrophage fuel the trip demands. The Kit's `RelativisticJourneyModel` is the
/// physics; this is the view-facing knobs, the sampled trajectory the worldtube
/// draws, and the two clocks.
@Observable
final class RelativityModel {
  private(set) var destinationIndex = 0
  /// Felt acceleration, in g (Earth gravities).
  var gForce = 1.0
  /// Astrophage packed, as log10 of ship-masses (the fuel spans a huge range, so
  /// the slider is logarithmic).
  var fuelLog = 2.0

  private(set) var samples: [RelativitySample] = []
  private(set) var revision = 0
  private(set) var discreteEventCount = 0

  private let sampleCount = 300

  var destination: Destination { Destination.all[destinationIndex] }

  private var journey: RelativisticJourneyModel {
    RelativisticJourneyModel(
      acceleration: RelativisticJourneyModel.naturalAccelerationPerG * gForce,
      distance: destination.distanceLightYears)
  }

  // The playhead sweeps the ship's own clock.
  var horizon: Double { journey.shipTimeTotal }
  var shipTimeTotal: Double { journey.shipTimeTotal }
  var earthTimeTotal: Double { journey.earthTimeTotal }
  var peakBeta: Double { journey.peakBeta }
  var peakGamma: Double { journey.peakGamma }
  var massRatio: Double { journey.massRatio }

  /// Astrophage needed above the payload, in ship-masses (the fuel is everything
  /// beyond the ship itself).
  var fuelNeeded: Double { max(0, massRatio - 1) }
  /// Astrophage packed, in ship-masses.
  var fuelPacked: Double { pow(10, fuelLog) }
  var hasEnoughFuel: Bool { fuelPacked >= fuelNeeded }

  init() {
    recompute()
  }

  /// Re-integrate the journey over the ship's proper time into a fresh trajectory.
  func recompute() {
    let journey = self.journey
    let dt = journey.shipTimeTotal / Double(sampleCount)
    let control = StepControl(relative: 1e-8, absolute: 1e-10)
    let trajectory = ODESolver.integrate(
      system: journey.system, initial: [0, 0], step: dt, count: sampleCount, control: control)
    let full = [[0.0, 0.0]] + trajectory  // the engine excludes the initial state
    samples = full.enumerated().map { index, state in
      let shipTime = Double(index) * dt
      return RelativitySample(
        shipYears: shipTime, earthYears: state[1], distanceLightYears: state[0],
        beta: journey.beta(at: shipTime))
    }
    revision += 1
  }

  /// The journey state at an arbitrary ship time (linear interpolation), for the
  /// clocks and the travelling spacecraft.
  func sample(at shipTime: Double) -> RelativitySample {
    guard samples.count > 1 else {
      return samples.first
        ?? RelativitySample(shipYears: 0, earthYears: 0, distanceLightYears: 0, beta: 0)
    }
    let dt = horizon / Double(sampleCount)
    let position = min(max(shipTime / dt, 0), Double(samples.count - 1))
    let index = min(Int(position), samples.count - 2)
    let blend = position - Double(index)
    let a = samples[index]
    let b = samples[index + 1]
    return RelativitySample(
      shipYears: shipTime,
      earthYears: a.earthYears + (b.earthYears - a.earthYears) * blend,
      distanceLightYears: a.distanceLightYears + (b.distanceLightYears - a.distanceLightYears)
        * blend,
      beta: a.beta + (b.beta - a.beta) * blend)
  }

  /// Where the spacecraft sits along the worldtube, `0...1` by ship time.
  func fraction(atShipTime shipTime: Double) -> Double {
    horizon > 0 ? min(max(shipTime / horizon, 0), 1) : 0
  }

  func selectDestination(_ index: Int) {
    destinationIndex = index
    discreteEventCount += 1
    recompute()
  }

  func reset() {
    gForce = 1
    fuelLog = 2
    discreteEventCount += 1
    recompute()
  }

  // MARK: - Readouts

  /// A one-line, plain-language read of the whole trip.
  var insight: String {
    let ship = Self.formatYears(shipTimeTotal)
    let earth = Self.formatYears(earthTimeTotal)
    return "You arrive in \(ship), but \(earth) pass back on Earth."
  }

  /// The fuel verdict line.
  var fuelVerdict: String {
    if hasEnoughFuel {
      return "Enough astrophage — you can accelerate and brake to arrive."
    }
    return "Not enough astrophage — you could never carry the fuel to stop there."
  }

  var speedText: String { Self.formatSpeed(peakBeta) }

  /// Years, in plain words: "6 years", "2.5 million years", "46.5 billion years".
  static func formatYears(_ years: Double) -> String {
    let value = abs(years)
    if value < 1 { return "a few months" }
    if value < 1000 { return "\(Int(value.rounded())) years" }
    let (scaled, word) = magnitude(value)
    let text = scaled < 10 ? String(format: "%.1f", scaled) : "\(Int(scaled.rounded()))"
    return "\(text) \(word) years"
  }

  /// A distance as a full phrase with units, from sub-light-year (Voyager) up to
  /// billions: "20 light-hours", "4.4 light-years", "26 thousand light-years",
  /// "2.5 million light-years", "18.2 billion light-years".
  static func formatDistance(_ lightYears: Double) -> String {
    let value = abs(lightYears)
    if value < 0.5 {
      let hours = value * 24 * 365.25
      if hours < 72 { return "\(Int(hours.rounded())) light-hours" }
      return "\(Int((value * 365.25).rounded())) light-days"
    }
    if value < 100 { return "\(String(format: "%.1f", value)) light-years" }
    if value < 1000 { return "\(Int(value.rounded())) light-years" }
    if value < 1e6 { return "\(Int((value / 1e3).rounded())) thousand light-years" }
    if value < 1e9 { return "\(scaled(value / 1e6)) million light-years" }
    if value < 1e12 { return "\(scaled(value / 1e9)) billion light-years" }
    return "\(scaled(value / 1e12)) trillion light-years"
  }

  private static func scaled(_ value: Double) -> String {
    value >= 100 ? "\(Int(value.rounded()))" : String(format: "%.1f", value)
  }

  /// A compact clock reading in years: "3.6 yr", "2.5M yr", "46.5B yr".
  static func compactYears(_ years: Double) -> String {
    let value = abs(years)
    if value < 1000 { return String(format: "%.1f yr", value) }
    if value < 1e6 { return String(format: "%.1fK yr", value / 1e3) }
    if value < 1e9 { return String(format: "%.1fM yr", value / 1e6) }
    if value < 1e12 { return String(format: "%.1fB yr", value / 1e9) }
    return String(format: "%.1fT yr", value / 1e12)
  }

  /// A big fuel multiple, compactly: "40×", "6.9 trillion×", "2 × 10²¹×".
  static func formatMultiple(_ value: Double) -> String {
    if value < 1000 { return "\(Int(value.rounded()))×" }
    if value < 1e15 {
      let (scaled, word) = magnitude(value)
      let text = scaled < 10 ? String(format: "%.1f", scaled) : "\(Int(scaled.rounded()))"
      return "\(text) \(word)×"
    }
    let exponent = Int(floor(log10(value)))
    let mantissa = value / pow(10, Double(exponent))
    return "\(String(format: "%.1f", mantissa)) × 10\(superscript(exponent))×"
  }

  /// Speed as a percentage of light: "95.17% of light speed", more nines as it
  /// climbs, and "essentially the speed of light" once it is too close to read.
  static func formatSpeed(_ beta: Double) -> String {
    let percent = beta * 100
    if percent >= 99.9999 { return "essentially the speed of light" }
    if percent >= 99.99 { return "\(String(format: "%.4f", percent))% of light speed" }
    return "\(String(format: "%.2f", percent))% of light speed"
  }

  private static func magnitude(_ value: Double) -> (Double, String) {
    switch value {
    case 1e12...: return (value / 1e12, "trillion")
    case 1e9...: return (value / 1e9, "billion")
    case 1e6...: return (value / 1e6, "million")
    default: return (value / 1e3, "thousand")
    }
  }

  private static func superscript(_ n: Int) -> String {
    let map: [Character: Character] = [
      "0": "\u{2070}", "1": "\u{00B9}", "2": "\u{00B2}", "3": "\u{00B3}", "4": "\u{2074}",
      "5": "\u{2075}", "6": "\u{2076}", "7": "\u{2077}", "8": "\u{2078}", "9": "\u{2079}",
    ]
    return String("\(n)".map { map[$0] ?? $0 })
  }
}
