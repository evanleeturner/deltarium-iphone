/// The Lorenz system — the canonical chaotic demonstrator:
///
///   dx/dt = σ(y − x),  dy/dt = x(ρ − z) − y,  dz/dt = xy − βz
///
/// The textbook chaotic regime is `σ = 10, ρ = 28, β = 8/3` (the default). The
/// tier-2 reference example runs a deeper-chaos regime (`ρ = 99.96, β = 2`),
/// which is where the phone's approximation and the Python truth visibly part
/// company past the Lyapunov time — the butterfly-effect lesson.
///
/// The right-hand side is `+ − × ÷` only, so a run is bit-identical across
/// platforms.
public struct LorenzModel {
  public var sigma: Double
  public var rho: Double
  public var beta: Double

  /// The classic chaotic parameters unless overridden.
  public init(sigma: Double = 10, rho: Double = 28, beta: Double = 8.0 / 3.0) {
    self.sigma = sigma
    self.rho = rho
    self.beta = beta
  }

  /// The right-hand side `f(t, [x, y, z]) -> [dx, dy, dz]`. Time-independent,
  /// so `t` is ignored.
  public func derivatives(_ t: Double, _ state: [Double]) -> [Double] {
    let x = state[0]
    let y = state[1]
    let z = state[2]
    return [sigma * (y - x), x * (rho - z) - y, x * y - beta * z]
  }

  /// The model as an `ODESystem` for the solver.
  public var system: ODESystem {
    ODESystem(dimension: 3, f: derivatives)
  }
}
