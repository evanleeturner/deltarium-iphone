/// A Lotka-Volterra system whose prey growth is driven by an external `food`
/// supply that changes over time:
///
///   dx/dt = A·food·x − B·x·y,   dy/dt = D·x·y − C·y
///
/// This is the tier-2 reference example (`example3`), where `food` is a monthly
/// time series. The driver holds `food` constant across each reporting interval
/// (one series sample per step), matching how the Python engine re-binds its
/// input row by row — so `system(food:)` builds the fixed-forcing system for a
/// single interval and `ODESolver.integrateForced` sweeps the series.
///
/// Right-hand side is `+ − × ÷` only, so a run is bit-identical across
/// platforms.
public struct DrivenLotkaVolterraModel {
  /// Prey growth rate (scaling the `food` term).
  public var a: Double
  /// Predation rate on prey.
  public var b: Double
  /// Predator death rate.
  public var c: Double
  /// Predator growth per predation.
  public var d: Double

  public init(a: Double = 1, b: Double = 1, c: Double = 1, d: Double = 1) {
    self.a = a
    self.b = b
    self.c = c
    self.d = d
  }

  /// The right-hand side for one interval, with `food` held constant. `f(t,
  /// [x, y]) -> [dx, dy]`; time-independent within the interval, so `t` is
  /// ignored.
  public func derivatives(food: Double, _ t: Double, _ state: [Double]) -> [Double] {
    let x = state[0]
    let y = state[1]
    return [a * food * x - b * x * y, d * x * y - c * y]
  }

  /// The fixed-forcing `ODESystem` for an interval whose supply is `food`.
  public func system(food: Double) -> ODESystem {
    ODESystem(dimension: 2) { t, state in self.derivatives(food: food, t, state) }
  }
}
