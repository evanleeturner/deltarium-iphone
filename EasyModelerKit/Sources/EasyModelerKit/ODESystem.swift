/// A first-order ODE system `dy/dt = f(t, y)`.
///
/// The state is a plain `[Double]` vector and `f` returns its componentwise
/// rate. This is the one shape every model reduces to and the only thing the
/// solver knows about — the models (Lotka-Volterra, Lorenz, the forced model)
/// are just factories that build an `ODESystem`, and time-varying forcing is
/// handled a reporting step at a time by rebuilding the system per interval
/// (see `ODESolver`), exactly as the Python engine re-binds its inputs each
/// step.
public struct ODESystem {
  /// The number of state components (`> 0`).
  public let dimension: Int

  /// The right-hand side `f(t, y) -> dy/dt`; its result has `dimension`
  /// components. Kept to `+ − × ÷` in every shipped model so a run is
  /// bit-identical on Linux-x86 and iOS-ARM.
  public let f: (Double, [Double]) -> [Double]

  public init(dimension: Int, f: @escaping (Double, [Double]) -> [Double]) {
    self.dimension = dimension
    self.f = f
  }
}
