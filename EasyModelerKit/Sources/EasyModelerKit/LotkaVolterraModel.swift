/// The Lotka-Volterra predator–prey system — the gentle, periodic counterpart
/// to Lorenz:
///
///   dx/dt = A·x − B·x·y,   dy/dt = D·x·y − C·y
///
/// with prey `x` and predator `y`. All four rate constants default to 1, which
/// is the tier-2 reference example (`example1`): closed orbits that neither
/// grow nor decay, so the phone and the Python truth stay together the whole
/// run. Right-hand side is `+ − × ÷` only, so a run is bit-identical across
/// platforms.
public struct LotkaVolterraModel {
  /// Prey growth rate.
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

  /// The right-hand side `f(t, [x, y]) -> [dx, dy]`. Time-independent, so `t`
  /// is ignored.
  public func derivatives(_ t: Double, _ state: [Double]) -> [Double] {
    let x = state[0]
    let y = state[1]
    return [a * x - b * x * y, d * x * y - c * y]
  }

  /// The model as an `ODESystem` for the solver.
  public var system: ODESystem {
    ODESystem(dimension: 2, f: derivatives)
  }
}
