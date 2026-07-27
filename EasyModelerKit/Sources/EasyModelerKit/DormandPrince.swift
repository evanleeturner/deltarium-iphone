/// The Dormand–Prince 5(4) adaptive Runge–Kutta integrator ("DOPRI5"): a
/// fifth-order solution with an embedded fourth-order error estimate that
/// chooses its own step size, plus dense output for smooth sampling.
///
/// It is the production replacement for the fixed-step RK4 seed. Every
/// operation on the trajectory is `+ − × ÷` or `squareRoot()`; the step
/// controller deliberately avoids `pow`/`exp` (which are not correctly rounded,
/// so they can differ by a bit across CPUs). Because IEEE `sqrt` *is* correctly
/// rounded, an entire adaptive run is bit-identical on Linux-x86 and iOS-ARM —
/// so CI validates the exact numbers the phone produces, and both can be
/// checked against the Python `port_reference` fixtures.
///
/// The reference for the tableau and the dense-output coefficients is Hairer,
/// Nørsett & Wanner, *Solving Ordinary Differential Equations I*, §II.5–II.6.
public enum DormandPrince {
  // MARK: Butcher tableau (nodes, stage weights, 5th-order weights)

  private static let c2 = 1.0 / 5, c3 = 3.0 / 10, c4 = 4.0 / 5, c5 = 8.0 / 9

  private static let a21 = 1.0 / 5
  private static let a31 = 3.0 / 40, a32 = 9.0 / 40
  private static let a41 = 44.0 / 45, a42 = -56.0 / 15, a43 = 32.0 / 9
  private static let a51 = 19372.0 / 6561, a52 = -25360.0 / 2187
  private static let a53 = 64448.0 / 6561, a54 = -212.0 / 729
  private static let a61 = 9017.0 / 3168, a62 = -355.0 / 33, a63 = 46732.0 / 5247
  private static let a64 = 49.0 / 176, a65 = -5103.0 / 18656

  // 5th-order solution weights (b2 = 0); the 7th stage weights match these
  // (b7 = 0), which is what makes the method first-same-as-last (FSAL).
  private static let b1 = 35.0 / 384, b3 = 500.0 / 1113, b4 = 125.0 / 192
  private static let b5 = -2187.0 / 6784, b6 = 11.0 / 84

  // Error weights e = b(5th) − b(4th); the estimate is e·k scaled by h.
  private static let e1 = 71.0 / 57600, e3 = -71.0 / 16695, e4 = 71.0 / 1920
  private static let e5 = -17253.0 / 339200, e6 = 22.0 / 525, e7 = -1.0 / 40

  // Dense-output coefficients (Hairer's `contd5`).
  private static let d1 = -12715105075.0 / 11282082432.0
  private static let d3 = 87487479700.0 / 32700410799.0
  private static let d4 = -10690763975.0 / 1880347072.0
  private static let d5 = 701980252875.0 / 199316789632.0
  private static let d6 = -1453857185.0 / 822651844.0
  private static let d7 = 69997945.0 / 29380423.0

  // MARK: One step

  /// The seven stage derivatives and the resulting 5th-order state and error
  /// estimate for a single step of size `h` from `(t, y)`. `k1` is supplied so
  /// the caller can reuse the previous step's end derivative (FSAL).
  struct StepResult {
    let yNext: [Double]
    let error: [Double]
    let k1: [Double]
    let k3: [Double]
    let k4: [Double]
    let k5: [Double]
    let k6: [Double]
    let k7: [Double]
  }

  static func step(
    _ system: ODESystem, t: Double, y: [Double], h: Double, k1: [Double]
  ) -> StepResult {
    let n = y.count
    let f = system.f

    func combine(_ terms: [(Double, [Double])]) -> [Double] {
      var out = y
      for i in 0..<n {
        var acc = y[i]
        for (weight, k) in terms {
          acc += h * weight * k[i]
        }
        out[i] = acc
      }
      return out
    }

    let k2 = f(t + c2 * h, combine([(a21, k1)]))
    let k3 = f(t + c3 * h, combine([(a31, k1), (a32, k2)]))
    let k4 = f(t + c4 * h, combine([(a41, k1), (a42, k2), (a43, k3)]))
    let k5 = f(t + c5 * h, combine([(a51, k1), (a52, k2), (a53, k3), (a54, k4)]))
    let k6 = f(
      t + h, combine([(a61, k1), (a62, k2), (a63, k3), (a64, k4), (a65, k5)]))

    var yNext = y
    for i in 0..<n {
      yNext[i] =
        y[i] + h * (b1 * k1[i] + b3 * k3[i] + b4 * k4[i] + b5 * k5[i] + b6 * k6[i])
    }
    let k7 = f(t + h, yNext)

    var error = y
    for i in 0..<n {
      error[i] =
        h
        * (e1 * k1[i] + e3 * k3[i] + e4 * k4[i] + e5 * k5[i] + e6 * k6[i]
          + e7 * k7[i])
    }
    return StepResult(
      yNext: yNext, error: error, k1: k1, k3: k3, k4: k4, k5: k5, k6: k6, k7: k7)
  }

  // MARK: Error norm and step scaling

  /// RMS of the per-component error scaled by `atol + rtol·max(|yStart|,
  /// |yEnd|)`. A value `≤ 1` means the step meets tolerance.
  static func errorNorm(
    _ error: [Double], yStart: [Double], yEnd: [Double], control: StepControl
  ) -> Double {
    var sum = 0.0
    for i in error.indices {
      let scale =
        control.absolute + control.relative * max(abs(yStart[i]), abs(yEnd[i]))
      let ratio = error[i] / scale
      sum += ratio * ratio
    }
    return (sum / Double(error.count)).squareRoot()
  }

  /// The step-scaling estimate `(1/errNorm)^(1/4)`, formed with two `sqrt`s so
  /// it stays in the correctly-rounded (bit-portable) family. The exponent only
  /// tunes how fast the step adapts — accuracy comes from the `≤ 1` accept test
  /// in the loop, not from this exponent — so trading the textbook `1/5` for a
  /// two-`sqrt` `1/4` costs at most a few extra steps and buys bit-portability.
  private static func scale(forErrorNorm errNorm: Double) -> Double {
    (1.0 / errNorm).squareRoot().squareRoot()
  }

  // MARK: Adaptive integration of one interval

  /// Integrate from `ta` to `tb` (with `tb > ta`), landing exactly on `tb`, and
  /// return the end state plus — when `collectDense` — a `DenseStep` per
  /// accepted step covering the interval.
  static func run(
    _ system: ODESystem,
    from ta: Double,
    to tb: Double,
    initial y0: [Double],
    control: StepControl,
    collectDense: Bool
  ) -> (end: [Double], dense: [DenseStep]) {
    var t = ta
    var y = y0
    var k1 = system.f(t, y)
    var h = tb - ta
    let dust = (tb - ta) * 1e-12
    var dense: [DenseStep] = []

    while t < tb - dust {
      if h > tb - t { h = tb - t }
      let result = step(system, t: t, y: y, h: h, k1: k1)
      let norm = errorNorm(result.error, yStart: y, yEnd: result.yNext, control: control)

      if norm <= 1.0 {
        if collectDense {
          dense.append(makeDense(t0: t, h: h, yStart: y, result: result))
        }
        t += h
        y = result.yNext
        k1 = result.k7
        let factor =
          norm == 0
          ? control.maxScale
          : min(control.maxScale, control.safety * scale(forErrorNorm: norm))
        h *= factor
      } else {
        h *= max(control.minScale, control.safety * scale(forErrorNorm: norm))
      }
    }
    return (y, dense)
  }

  private static func makeDense(
    t0: Double, h: Double, yStart: [Double], result: StepResult
  ) -> DenseStep {
    let n = yStart.count
    var c3 = yStart
    var c4 = yStart
    var c5 = yStart
    for i in 0..<n {
      let diff = result.yNext[i] - yStart[i]
      let bspl = h * result.k1[i] - diff
      c3[i] = bspl
      c4[i] = diff - h * result.k7[i] - bspl
      c5[i] =
        h
        * (d1 * result.k1[i] + d3 * result.k3[i] + d4 * result.k4[i]
          + d5 * result.k5[i] + d6 * result.k6[i] + d7 * result.k7[i])
    }
    return DenseStep(t0: t0, h: h, yStart: yStart, yEnd: result.yNext, c3: c3, c4: c4, c5: c5)
  }

  // MARK: Public entry points

  /// Integrate `system` from `ta` to `tb` and return the state at `tb`.
  public static func solve(
    _ system: ODESystem,
    from ta: Double,
    to tb: Double,
    initial y0: [Double],
    control: StepControl = .standard
  ) -> [Double] {
    guard tb > ta else { return y0 }
    return run(system, from: ta, to: tb, initial: y0, control: control, collectDense: false).end
  }

  /// Integrate `system` from `ta` to `tb` and return the dense-output steps
  /// spanning the interval, for smooth sampling at any resolution.
  public static func denseSolution(
    _ system: ODESystem,
    from ta: Double,
    to tb: Double,
    initial y0: [Double],
    control: StepControl = .standard
  ) -> [DenseStep] {
    guard tb > ta else { return [] }
    return run(system, from: ta, to: tb, initial: y0, control: control, collectDense: true).dense
  }
}
