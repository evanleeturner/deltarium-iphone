/// The gravitational three-body problem — three point masses pulling on each
/// other by Newton's law of gravity. It has no closed-form solution in general,
/// yet special starts give perfect order: the **figure-8 choreography**, three
/// equal masses chasing each other forever round a single looping 8. Nudge the
/// start and the order dissolves into chaos — the playground's teaching arc.
///
/// The state is a flat 18-vector — three bodies, each a 3-D position, then (after
/// all three positions) a 3-D velocity:
///
///   `[x0,y0,z0, x1,y1,z1, x2,y2,z2,  vx0,vy0,vz0, vx1,vy1,vz1, vx2,vy2,vz2]`
///
/// so `state[0..<9]` are the positions and `state[9..<18]` the velocities. This
/// matches the tier-2 Python oracle (`easymodeler/examples/three_body.py`) exactly,
/// so the fidelity fixture lines up component for component.
///
/// The pull is **Plummer-softened**: each pair uses `1 / (r² + ε²)^{3/2}` in place
/// of `1 / r³`, so a close approach can never diverge to infinity — the toy stays
/// finite and playable. The right-hand side is `+ − × ÷` and `sqrt` only (no
/// `exp`/`pow`), and `sqrt` is IEEE correctly-rounded, so a run is bit-identical
/// across Linux-x86 and iOS-ARM, like the Lotka-Volterra and Lorenz models.
public struct ThreeBodyModel {
  /// The three body masses.
  public var masses: (Double, Double, Double)
  /// The gravitational constant (natural units; `1` for the canonical configs).
  public var g: Double
  /// The Plummer softening length ε — floors the pair distance so the force
  /// stays finite through a close approach.
  public var softening: Double

  public init(
    masses: (Double, Double, Double) = (1, 1, 1), g: Double = 1, softening: Double = 1e-3
  ) {
    self.masses = masses
    self.g = g
    self.softening = softening
  }

  /// The right-hand side `f(t, state) -> d/dt state`. Autonomous, so `t` is
  /// ignored: the position derivatives are the velocities and each body's
  /// velocity derivative is the softened pull of the other two.
  public func derivatives(_ t: Double, _ state: [Double]) -> [Double] {
    let mass = [masses.0, masses.1, masses.2]
    let eps2 = softening * softening

    var acceleration = [[0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0]]
    for i in 0..<3 {
      for j in 0..<3 where j != i {
        let dx = state[3 * j] - state[3 * i]
        let dy = state[3 * j + 1] - state[3 * i + 1]
        let dz = state[3 * j + 2] - state[3 * i + 2]
        let r2 = dx * dx + dy * dy + dz * dz + eps2
        let pull = g * mass[j] / (r2 * r2.squareRoot())
        acceleration[i][0] += dx * pull
        acceleration[i][1] += dy * pull
        acceleration[i][2] += dz * pull
      }
    }

    var derivative = Array(state[9..<18])  // position rates = velocities
    for body in acceleration {
      derivative.append(contentsOf: body)
    }
    return derivative
  }

  /// The model as an `ODESystem` for the solver.
  public var system: ODESystem {
    ODESystem(dimension: 18, f: derivatives)
  }

  /// The total mechanical energy (kinetic + softened potential) of a state — a
  /// conserved quantity of the true dynamics. A non-symplectic solver lets it
  /// wander only slowly, so how little it drifts is the run's honest-numerics fence
  /// (and the phone can show it holding steady).
  public func totalEnergy(_ state: [Double]) -> Double {
    let mass = [masses.0, masses.1, masses.2]
    let eps2 = softening * softening

    var kinetic = 0.0
    for i in 0..<3 {
      let vx = state[9 + 3 * i]
      let vy = state[9 + 3 * i + 1]
      let vz = state[9 + 3 * i + 2]
      kinetic += 0.5 * mass[i] * (vx * vx + vy * vy + vz * vz)
    }

    var potential = 0.0
    for i in 0..<3 {
      for j in (i + 1)..<3 {
        let dx = state[3 * i] - state[3 * j]
        let dy = state[3 * i + 1] - state[3 * j + 1]
        let dz = state[3 * i + 2] - state[3 * j + 2]
        potential -= g * mass[i] * mass[j] / (dx * dx + dy * dy + dz * dz + eps2).squareRoot()
      }
    }
    return kinetic + potential
  }
}
