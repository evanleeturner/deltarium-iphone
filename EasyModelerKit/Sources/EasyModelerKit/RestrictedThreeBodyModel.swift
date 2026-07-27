/// The circular restricted three-body problem (CR3BP) in the rotating frame — the
/// engine behind the Lagrange-point playground. Two primaries (Earth and Moon) are
/// fixed on the x-axis and a massless satellite drifts in their combined pull, seen
/// from the frame co-rotating with them. In that frame five equilibrium points
/// appear — the Lagrange points (see `EarthMoonSystem`).
///
/// State is `[x, y, z, vx, vy, vz]` in non-dimensional units (total mass 1,
/// Earth–Moon distance 1, angular rate 1), matching the tier-2 oracle
/// `easymodeler/examples/lagrange.py`. The acceleration carries the two-body pull
/// plus the rotating frame's Coriolis (`±2v`) and centrifugal (`x`, `y`) terms.
///
/// The right-hand side is `+ − × ÷` and `sqrt` only — no `exp`/`pow` — so a run is
/// bit-identical across Linux and iOS, like the Lotka-Volterra, Lorenz, and
/// three-body models.
public struct RestrictedThreeBodyModel {
  /// The Moon's mass fraction `μ = m_moon / (m_earth + m_moon)`. Earth sits at
  /// `(-μ, 0, 0)`, the Moon at `(1-μ, 0, 0)`.
  public var mu: Double

  public init(mu: Double = EarthMoonSystem.mu) {
    self.mu = mu
  }

  /// The right-hand side `f(t, state) -> d/dt state`. Autonomous, so `t` is
  /// ignored: the position derivatives are the velocities, and the acceleration is
  /// the two-body pull plus the Coriolis and centrifugal terms.
  public func derivatives(_ t: Double, _ state: [Double]) -> [Double] {
    let x = state[0]
    let y = state[1]
    let z = state[2]
    let vx = state[3]
    let vy = state[4]
    let vz = state[5]

    let dxEarth = x + mu
    let dxMoon = x - (1 - mu)
    let r1sq = dxEarth * dxEarth + y * y + z * z
    let r2sq = dxMoon * dxMoon + y * y + z * z
    let pullEarth = (1 - mu) / (r1sq * r1sq.squareRoot())
    let pullMoon = mu / (r2sq * r2sq.squareRoot())

    let ax = 2 * vy + x - pullEarth * dxEarth - pullMoon * dxMoon
    let ay = -2 * vx + y - pullEarth * y - pullMoon * y
    let az = -pullEarth * z - pullMoon * z
    return [vx, vy, vz, ax, ay, az]
  }

  /// The model as an `ODESystem` for the solver.
  public var system: ODESystem {
    ODESystem(dimension: 6, f: derivatives)
  }

  /// The Jacobi constant `C = x² + y² + 2(1-μ)/r1 + 2μ/r2 - v²` — the rotating
  /// frame's conserved quantity (the analog of energy), so how little it drifts is
  /// the run's honest-numerics fence.
  public func jacobiConstant(_ state: [Double]) -> Double {
    let x = state[0]
    let y = state[1]
    let z = state[2]
    let speedSq = state[3] * state[3] + state[4] * state[4] + state[5] * state[5]
    let r1 = ((x + mu) * (x + mu) + y * y + z * z).squareRoot()
    let r2 = ((x - (1 - mu)) * (x - (1 - mu)) + y * y + z * z).squareRoot()
    return x * x + y * y + 2 * (1 - mu) / r1 + 2 * mu / r2 - speedSq
  }
}
