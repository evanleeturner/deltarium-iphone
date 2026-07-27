/// A radioactive decay chain as a coupled linear ODE (the Bateman system): each
/// member decays into the next, and the last member is stable. A radioactive
/// nucleus does not simply vanish — it becomes a daughter that is usually
/// radioactive too — so the activity lingers down the chain until it reaches a
/// stable isotope.
///
///   `dN_i/dt = -λ_i N_i + λ_{i-1} N_{i-1}`   (decays out, and is fed by its parent)
///
/// The right-hand side is `+ − ×` only — no `exp`/`sqrt` — so a run is bit-identical
/// across Linux and iOS, like the other pure-arithmetic models. Ultra-fast daughters
/// are folded into their parent by secular equilibrium (see `RadiationSource`), so
/// every modeled chain is non-stiff and the general solver handles it directly.
public struct DecayChainModel {
  /// The decay constant λ for each chain member, in order; the stable end is 0.
  public var decayConstants: [Double]

  public init(decayConstants: [Double]) {
    self.decayConstants = decayConstants
  }

  /// The right-hand side `f(t, state) -> d/dt state`. Autonomous, so `t` is ignored:
  /// each member loses `λ_i N_i` and hands it to the next member down the chain.
  public func derivatives(_ t: Double, _ state: [Double]) -> [Double] {
    var derivative = [Double](repeating: 0, count: state.count)
    for i in state.indices {
      let out = decayConstants[i] * state[i]
      derivative[i] -= out
      if i + 1 < state.count { derivative[i + 1] += out }
    }
    return derivative
  }

  /// The model as an `ODESystem` for the solver.
  public var system: ODESystem {
    ODESystem(dimension: decayConstants.count, f: derivatives)
  }
}
