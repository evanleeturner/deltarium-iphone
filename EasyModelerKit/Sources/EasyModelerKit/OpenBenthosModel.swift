#if canImport(Darwin)
  import Darwin
#elseif canImport(Glibc)
  import Glibc
#endif

/// The phone playground's model: the Benthic Ecology Model benthos made into an
/// **open** nutrient system, so it tracks the seasons instead of settling.
///
/// State is `[N, B]` — a nutrient/food pool and benthic biomass. Growth is the
/// BEM's environmental response (Gaussian salinity and temperature optima, real
/// Rincon Bayou coefficients) times a Michaelis–Menten food limitation and a
/// logistic ceiling. Nitrogen enters as a fixed `food` supply and leaves by
/// burial and the un-recycled part of mortality — an open budget. A small
/// `recruitment` trickle (larvae drifting in) lets biomass recover from a total
/// wipeout, which growth alone (∝ B) could not.
///
/// Unlike the other Kit models, the right-hand side uses `exp` for the Gaussian
/// forcing, so it is **not** bit-identical across platforms — the fidelity
/// contract here is agreement to tolerance against the Python `vode` reference
/// (the parity check measured the Dormand–Prince drift at ~1e-4 over the year),
/// not the bit-exactness the pure-arithmetic models hold. This is a teaching toy
/// whose numbers are meant to be moved with sliders, not a bit-exact port.
///
/// It is a forced model: `system(temperature:salinity:)` builds the fixed-forcing
/// system for one reporting interval and `ODESolver.integrateForced` sweeps the
/// seasonal series, exactly as the driven Lotka–Volterra model does with `food`.
public struct OpenBenthosModel {
  /// Maximum benthic growth scalar (`Kg`).
  public var growthScale: Double
  /// Carrying capacity (`Bcc`); the logistic ceiling on biomass.
  public var carryingCapacity: Double
  /// Salinity growth width (`Kgs`); the spread of the salinity optimum.
  public var salinityWidth: Double
  /// Temperature growth width (`Kgt`); the spread of the temperature optimum.
  public var temperatureWidth: Double
  /// Linear mortality rate (`Km`).
  public var mortality: Double
  /// Optimal salinity (`Sopt`), where the salinity growth factor peaks.
  public var optimalSalinity: Double
  /// Optimal temperature (`Topt`), where the temperature growth factor peaks.
  public var optimalTemperature: Double
  /// Food half-saturation (`kN`) for the Michaelis–Menten nutrient limitation.
  public var foodHalfSaturation: Double
  /// Daily nutrient input into the pool — the "food" slider.
  public var foodInput: Double
  /// Burial / out-of-column loss rate on the nutrient pool.
  public var burial: Double
  /// Fraction of mortality recycled back to the nutrient pool (rest is buried).
  public var recycle: Double
  /// Larval recruitment from outside — a small biomass trickle for recovery.
  public var recruitment: Double

  /// Defaults are the paper's fitted *Streblospio benedicti* coefficients
  /// (Table 4) plus playground values for the open-system knobs; these must
  /// match the tier-2 oracle (`easymodeler/examples/bem_open.py`) for the
  /// fidelity fence to hold.
  public init(
    growthScale: Double = 8.78,
    carryingCapacity: Double = 12,
    salinityWidth: Double = 2.94,
    temperatureWidth: Double = 5.48,
    mortality: Double = 0.23,
    optimalSalinity: Double = 13.47,
    optimalTemperature: Double = 16.47,
    foodHalfSaturation: Double = 3,
    foodInput: Double = 3,
    burial: Double = 0.1,
    recycle: Double = 0.5,
    recruitment: Double = 0.02
  ) {
    self.growthScale = growthScale
    self.carryingCapacity = carryingCapacity
    self.salinityWidth = salinityWidth
    self.temperatureWidth = temperatureWidth
    self.mortality = mortality
    self.optimalSalinity = optimalSalinity
    self.optimalTemperature = optimalTemperature
    self.foodHalfSaturation = foodHalfSaturation
    self.foodInput = foodInput
    self.burial = burial
    self.recycle = recycle
    self.recruitment = recruitment
  }

  /// The right-hand side for one interval, with `temperature` and `salinity`
  /// held constant. `f(t, [N, B]) -> [dN, dB]`; time-independent within the
  /// interval, so `t` is ignored.
  public func derivatives(
    temperature: Double, salinity: Double, _ t: Double, _ state: [Double]
  ) -> [Double] {
    let nutrient = state[0]
    let biomass = state[1]

    let salinityOffset = salinity - optimalSalinity
    let temperatureOffset = temperature - optimalTemperature
    let salinityDenominator = (2 * salinityWidth) * (2 * salinityWidth)
    let temperatureDenominator = (2 * temperatureWidth) * (2 * temperatureWidth)
    let gsal = exp(-(salinityOffset * salinityOffset) / salinityDenominator)
    let gtemp = exp(-(temperatureOffset * temperatureOffset) / temperatureDenominator)

    let saturation = foodHalfSaturation + nutrient
    let foodLimit = saturation > 0 ? nutrient / saturation : 0

    let growth = growthScale * gsal * gtemp * foodLimit * biomass * (1 - biomass / carryingCapacity)
    let death = mortality * biomass

    let dNutrient = foodInput - growth + recycle * death - burial * nutrient
    let dBiomass = growth - death + recruitment
    return [dNutrient, dBiomass]
  }

  /// The fixed-forcing `ODESystem` for an interval at the given conditions.
  public func system(temperature: Double, salinity: Double) -> ODESystem {
    ODESystem(dimension: 2) { t, state in
      self.derivatives(temperature: temperature, salinity: salinity, t, state)
    }
  }
}
