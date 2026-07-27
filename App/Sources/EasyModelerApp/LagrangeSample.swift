import simd

/// One sampled instant of the Lagrange run: the time and the five satellites'
/// positions (one launched from each of L1–L5), in `Float` for SceneKit.
/// `Identifiable` by time so views can key it.
struct LagrangeSample: Identifiable {
  let t: Double
  /// The five satellite positions, in L1…L5 order.
  let positions: [SIMD3<Float>]

  var id: Double { t }
}
