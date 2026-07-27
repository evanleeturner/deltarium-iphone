#if canImport(Darwin)
  import Darwin
#elseif canImport(Glibc)
  import Glibc
#endif

/// A relativistic interstellar journey at constant proper acceleration — the
/// "flip and burn": accelerate to the midpoint, flip, and decelerate to arrive
/// at rest. Special relativity's time dilation made into a journey you can
/// watch: the ship's own clock falls far behind Earth's as its speed climbs
/// toward the speed of light.
///
/// Worked in natural units (c = 1): distance in light-years, time in years,
/// proper acceleration in c per year (1 g ≈ 1.032, the famous "1 g is about a
/// light-year per year squared"). The state is integrated over the ship's own
/// **proper time** τ, which is far better conditioned than coordinate time for
/// the distant targets — there the ship spends almost the entire trip a hair
/// below c, where a coordinate-time integration loses all its precision. Over τ
/// the equations are the smooth
///
///   dx/dτ = sinh(φ),   dt/dτ = cosh(φ),   φ(τ) = α · min(τ, τ_total − τ)
///
/// where φ is the rapidity (it ramps up on the outbound burn and back down on
/// the braking burn), `x` is the distance covered, and `t` is Earth (coordinate)
/// time. Because it uses `sinh`/`cosh`, the fidelity contract — like
/// `OpenBenthosModel` — is agreement to tolerance against the exact closed form,
/// not the bit-exactness the pure-arithmetic models hold. The closed form here
/// is itself exact (the relativistic-rocket equations), so it is the oracle.
public struct RelativisticJourneyModel {
  /// Proper acceleration, in units of c per year (1 g ≈ 1.032).
  public var acceleration: Double
  /// One-way distance to the destination, in light-years.
  public var distance: Double

  /// The proper acceleration of 1 g in natural units — light-years per year²
  /// (Julian year, CODATA c). Numerically ≈ 1.0323, the "1 g ≈ 1 ly/yr²" fact.
  public static let naturalAccelerationPerG =
    9.80665 * 365.25 * 86400 / 299_792_458.0

  public init(
    acceleration: Double = RelativisticJourneyModel.naturalAccelerationPerG,
    distance: Double = 4.37
  ) {
    self.acceleration = acceleration
    self.distance = distance
  }

  // MARK: - Closed form (the exact oracle)

  /// Ship proper time to the flip: accelerate over half the distance.
  public var shipTimeToFlip: Double {
    acosh(1 + acceleration * distance / 2) / acceleration
  }
  /// Total ship (proper) time for the whole trip.
  public var shipTimeTotal: Double { 2 * shipTimeToFlip }
  /// Total Earth (coordinate) time for the whole trip.
  public var earthTimeTotal: Double {
    2 * sinh(acceleration * shipTimeToFlip) / acceleration
  }
  /// Peak speed at the flip, as a fraction of c.
  public var peakBeta: Double { tanh(acceleration * shipTimeToFlip) }
  /// Peak Lorentz factor at the flip (equals 1 + α·D/2).
  public var peakGamma: Double { cosh(acceleration * shipTimeToFlip) }
  /// Fuel mass ratio for an ideal photon rocket flying the flip-and-burn (there
  /// and stopped): initial mass / payload mass. The `exp` form is overflow-safe
  /// even where β rounds to 1.
  public var massRatio: Double { exp(2 * acceleration * shipTimeToFlip) }

  /// Speed (fraction of c) at ship proper time τ.
  public func beta(at tau: Double) -> Double { tanh(rapidity(tau)) }
  /// Lorentz factor at ship proper time τ.
  public func gamma(at tau: Double) -> Double { cosh(rapidity(tau)) }

  // MARK: - The ODE (over ship proper time τ)

  /// The rapidity at ship proper time τ — ramps up to the flip, then back down.
  private func rapidity(_ tau: Double) -> Double {
    acceleration * min(tau, shipTimeTotal - tau)
  }

  /// `dx/dτ`, `dt/dτ` over ship proper time. State is `[x (ly), t (Earth yr)]`;
  /// both start at 0.
  public func derivatives(_ tau: Double, _ state: [Double]) -> [Double] {
    let phi = rapidity(tau)
    return [sinh(phi), cosh(phi)]
  }

  /// The journey as an `ODESystem` for the solver, integrated over τ.
  public var system: ODESystem { ODESystem(dimension: 2, f: derivatives) }
}
