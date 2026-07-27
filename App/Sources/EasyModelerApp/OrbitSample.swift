import simd

/// One sampled instant of a three-body run: the time and the three body
/// positions, already in `Float` for SceneKit. Built from the Kit's 18-component
/// state, whose first nine entries are the three positions. `Identifiable` by time
/// so views can key it.
struct OrbitSample: Identifiable {
  let t: Double
  /// The three body positions, in order.
  let positions: [SIMD3<Float>]

  var id: Double { t }

  init(t: Double, state: [Double]) {
    self.t = t
    self.positions = (0..<3).map { body in
      SIMD3<Float>(
        Float(state[3 * body]), Float(state[3 * body + 1]), Float(state[3 * body + 2]))
    }
  }
}
