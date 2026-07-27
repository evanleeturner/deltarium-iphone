/// The reporting driver over `DormandPrince`: integrate a model on a uniform
/// time grid and hand back the state at each grid point.
///
/// It reproduces the tier-2 Python engine's reporting convention so the two can
/// be compared point for point: each reporting interval is integrated on its
/// own (the adaptive solver restarts at every grid point, landing exactly on
/// it), the driving forcing is held constant across its interval, and the
/// **initial state is not included** in the result — the first row is the state
/// after the first step, exactly as `Model.integrate` returns it.
public enum ODESolver {
  /// Integrate an autonomous `system` over `count` reporting steps of width
  /// `dt` from `t = 0`, returning the state after each step (length `count`).
  public static func integrate(
    system: ODESystem,
    initial: [Double],
    step dt: Double,
    count: Int,
    control: StepControl = .standard
  ) -> [[Double]] {
    reportingIntegrate(
      systemAt: { _ in system }, initial: initial, step: dt, count: count,
      control: control)
  }

  /// Integrate a forced model whose right-hand side changes each interval:
  /// interval `i` uses `systemFor(forcings[i])`, integrated with that forcing
  /// held constant — matching the Python engine, which re-binds its inputs row
  /// by row. Returns one state per forcing sample (length `forcings.count`).
  public static func integrateForced<Forcing>(
    systemFor: (Forcing) -> ODESystem,
    initial: [Double],
    forcings: [Forcing],
    step dt: Double,
    control: StepControl = .standard
  ) -> [[Double]] {
    reportingIntegrate(
      systemAt: { systemFor(forcings[$0]) }, initial: initial, step: dt,
      count: forcings.count, control: control)
  }

  /// The shared loop: step across each interval `[i·dt, (i+1)·dt]`, threading
  /// the running state forward and recording each grid-point state.
  private static func reportingIntegrate(
    systemAt: (Int) -> ODESystem,
    initial: [Double],
    step dt: Double,
    count: Int,
    control: StepControl
  ) -> [[Double]] {
    var state = initial
    var trajectory: [[Double]] = []
    trajectory.reserveCapacity(count)
    for i in 0..<count {
      let ta = Double(i) * dt
      let tb = Double(i + 1) * dt
      state = DormandPrince.solve(
        systemAt(i), from: ta, to: tb, initial: state, control: control)
      trajectory.append(state)
    }
    return trajectory
  }
}
