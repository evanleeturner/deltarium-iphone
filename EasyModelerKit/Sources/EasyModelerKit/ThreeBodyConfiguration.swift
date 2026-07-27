/// A named starting arrangement for the three-body problem: the three masses, the
/// softening, and the 18-component initial state (three positions, then three
/// velocities — the layout `ThreeBodyModel` reads). These are the physics
/// constants shared by the fidelity test and the app's presets, so the numbers
/// live in one place; they must equal the tier-2 oracle
/// (`easymodeler/examples/three_body.py`) for the figure-8 fixture to line up.
public struct ThreeBodyConfiguration: Sendable {
  public let masses: (Double, Double, Double)
  public let softening: Double
  /// `[x0,y0,z0, x1,y1,z1, x2,y2,z2,  vx0,vy0,vz0, vx1,vy1,vz1, vx2,vy2,vz2]`.
  public let initialState: [Double]

  public init(masses: (Double, Double, Double), softening: Double, initialState: [Double]) {
    self.masses = masses
    self.softening = softening
    self.initialState = initialState
  }

  /// The model (with `G = 1`) for these masses and softening.
  public var model: ThreeBodyModel {
    ThreeBodyModel(masses: masses, g: 1, softening: softening)
  }

  /// The stable figure-8 choreography (Chenciner & Montgomery; Simó's data):
  /// three equal masses tracing one looping 8 forever. Period ≈ 6.3259.
  public static let figureEight = ThreeBodyConfiguration(
    masses: (1, 1, 1), softening: 1e-3,
    initialState: [
      -0.97000436, 0.24308753, 0,
      0.97000436, -0.24308753, 0,
      0, 0, 0,
      0.4662036850, 0.4323657300, 0,
      0.4662036850, 0.4323657300, 0,
      -0.93240737, -0.86473146, 0,
    ])

  /// The Pythagorean (Burrau) problem: masses 3-4-5 at the corners of a 3-4-5
  /// right triangle, released from rest — a chaotic binary-and-ejection scramble.
  public static let pythagorean = ThreeBodyConfiguration(
    masses: (3, 4, 5), softening: 3e-2,
    initialState: [
      1, 3, 0,
      -2, -1, 0,
      1, -1, 0,
      0, 0, 0,
      0, 0, 0,
      0, 0, 0,
    ])

  /// A genuinely three-dimensional tangle — three equal masses launched out of a
  /// single plane, so the orbit fills space rather than staying flat.
  public static let tangle = ThreeBodyConfiguration(
    masses: (1, 1, 1), softening: 2e-2,
    initialState: [
      1, 0, 0.2,
      -1, 0, -0.2,
      0, 0.4, 0,
      0, 0.5, 0.15,
      0, -0.5, 0.15,
      0, 0, -0.30,
    ])
}
