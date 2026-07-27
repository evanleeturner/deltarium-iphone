import Foundation

/// One Lagrange point of the Earth–Moon system: its name and its position in the
/// rotating frame (the z-component is 0 — they all lie in the orbital plane).
public struct LagrangePoint: Sendable {
  public let name: String
  public let position: [Double]

  public init(name: String, position: [Double]) {
    self.name = name
    self.position = position
  }
}

/// The fixed Earth–Moon system the satellite playground runs in: the mass
/// parameter, the primaries' positions, and the five Lagrange points. These are
/// the shared physics constants for the app and the fidelity test; they must equal
/// the tier-2 oracle `easymodeler/examples/lagrange.py`.
public enum EarthMoonSystem {
  /// The Moon's mass fraction `μ` (JPL Earth–Moon value).
  public static let mu = 0.012150585609624

  /// One synodic period in non-dimensional time (the primaries' rotation).
  public static let period = 2 * Double.pi

  /// Earth's fixed position in the rotating frame.
  public static let earthPosition = [-mu, 0.0, 0.0]
  /// The Moon's fixed position in the rotating frame.
  public static let moonPosition = [1 - mu, 0.0, 0.0]

  /// The five Lagrange points. L1–L3 are collinear (Newton from the standard first
  /// guesses); L4/L5 are the exact equilateral points 60° ahead of and behind the
  /// Moon. L4/L5 are stable for this mass ratio; L1/L2/L3 are not.
  public static let lagrangePoints: [LagrangePoint] = [
    LagrangePoint(name: "L1", position: [collinearRoot(guess: (1 - mu) - cubeGuess), 0, 0]),
    LagrangePoint(name: "L2", position: [collinearRoot(guess: (1 - mu) + cubeGuess), 0, 0]),
    LagrangePoint(name: "L3", position: [collinearRoot(guess: -(1 + 5 * mu / 12)), 0, 0]),
    LagrangePoint(name: "L4", position: [0.5 - mu, (3.0).squareRoot() / 2, 0]),
    LagrangePoint(name: "L5", position: [0.5 - mu, -(3.0).squareRoot() / 2, 0]),
  ]

  /// The satellite's initial state at a Lagrange point with a launch delta-v.
  public static func launchState(at point: LagrangePoint, deltaV: [Double]) -> [Double] {
    point.position + deltaV
  }

  private static let cubeGuess = pow(mu / 3, 1.0 / 3.0)

  /// Newton's method for a collinear Lagrange point on the x-axis, where the net
  /// rotating-frame force `x - (1-μ)(x+μ)/|x+μ|³ - μ(x-1+μ)/|x-1+μ|³` vanishes.
  /// The residual reaches machine precision, so a satellite placed here (with zero
  /// velocity) is a true equilibrium.
  private static func collinearRoot(guess: Double) -> Double {
    var x = guess
    for _ in 0..<60 {
      let a = x + mu
      let b = x - (1 - mu)
      let aa = abs(a)
      let bb = abs(b)
      let ra3 = aa * aa * aa
      let rb3 = bb * bb * bb
      let f = x - (1 - mu) * a / ra3 - mu * b / rb3
      // d/dx [u/|u|³] = -2/|u|³, so f'(x) = 1 + 2(1-μ)/|a|³ + 2μ/|b|³.
      let fp = 1 + 2 * (1 - mu) / ra3 + 2 * mu / rb3
      let step = f / fp
      x -= step
      if abs(step) < 1e-15 { break }
    }
    return x
  }
}
