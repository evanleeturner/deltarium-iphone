/// The continuous extension of one accepted Dormand–Prince step: a 4th-order
/// polynomial that reads the solution back at any time inside `[t0, t0 + h]`,
/// without re-integrating.
///
/// This is the "dense output" the app uses to draw smooth curves — the
/// attractor stays smooth between the solver's own (unevenly spaced) steps, and
/// a plot can be sampled at whatever resolution the screen needs. It is the
/// standard Hairer `dopri5` interpolant, built from the step's endpoints and
/// two of its stage derivatives, so it costs no extra right-hand-side calls.
public struct DenseStep {
  /// Start time of the step.
  public let t0: Double

  /// Step size (`> 0`); the step covers `[t0, t0 + h]`.
  public let h: Double

  /// State at `t0` (the interpolant's value at `theta = 0`).
  public let yStart: [Double]

  /// State at `t0 + h` (the interpolant's value at `theta = 1`).
  public let yEnd: [Double]

  // The remaining Horner coefficients of the interpolant (`rcont3..5` in
  // Hairer's notation); `rcont1 = yStart`, `rcont2 = yEnd - yStart`.
  let c3: [Double]
  let c4: [Double]
  let c5: [Double]

  /// The state at time `t`, with `t` clamped into `[t0, t0 + h]`.
  ///
  /// At the endpoints this returns `yStart` / `yEnd` exactly (theta 0 / 1).
  public func sample(at t: Double) -> [Double] {
    let theta = max(0.0, min(1.0, (t - t0) / h))
    let s1 = 1.0 - theta
    var result = yStart
    for i in yStart.indices {
      let rcont2 = yEnd[i] - yStart[i]
      result[i] =
        yStart[i]
        + theta * (rcont2 + s1 * (c3[i] + theta * (c4[i] + s1 * c5[i])))
    }
    return result
  }
}
