import Testing

@testable import EasyModelerKit

/// Fences on the reporting driver: the grid convention (initial state excluded,
/// one row per step), the forced sweep, and that the reporting density does not
/// change the underlying solution.
struct ODESolverTests {
  /// The result has one row per step, each the model's dimension, and the first
  /// row is the state *after* the first step — the initial state is not
  /// included, matching the tier-2 engine.
  @Test func integrateExcludesInitialAndShapesPerStep() {
    let initial = [3.0, 2.0]
    let trajectory = ODESolver.integrate(
      system: LotkaVolterraModel().system, initial: initial, step: 1.0, count: 20)
    #expect(trajectory.count == 20, "one row per reporting step")
    #expect(trajectory.allSatisfy { $0.count == 2 }, "each row is the state vector")
    #expect(trajectory[0] != initial, "the first row is post-step, not the initial state")
  }

  /// A forced sweep returns one row per forcing sample.
  @Test func integrateForcedCountsWithForcing() {
    let model = DrivenLotkaVolterraModel()
    let foods = [0.5, 0.7, 0.2, 0.9]
    let trajectory = ODESolver.integrateForced(
      systemFor: model.system(food:), initial: [3, 2], forcings: foods, step: 1.0)
    #expect(trajectory.count == foods.count, "one row per forcing sample")
  }

  /// Reporting density is cosmetic: integrating the same horizon on a finer grid
  /// lands on the same final state (the adaptive solver restarts each interval,
  /// but the solution it traces is the same).
  @Test func reportingDensityDoesNotChangeTheSolution() {
    let system = LotkaVolterraModel().system
    let coarse = ODESolver.integrate(system: system, initial: [3, 2], step: 1.0, count: 20)
    let fine = ODESolver.integrate(system: system, initial: [3, 2], step: 0.5, count: 40)
    // Both end at t = 20.
    let endCoarse = coarse[coarse.count - 1]
    let endFine = fine[fine.count - 1]
    #expect(
      isClose(endCoarse[0], endFine[0], tolerance: 1e-6)
        && isClose(endCoarse[1], endFine[1], tolerance: 1e-6),
      "coarse and fine grids reach the same state at the same time")
  }

  /// The driver reproduces a closed form: `y' = -y` on a 100-step grid reaches
  /// `e^{-1}` at `t = 1`.
  @Test func integrateReproducesClosedForm() {
    let decay = ODESystem(dimension: 1) { _, y in [-y[0]] }
    let trajectory = ODESolver.integrate(system: decay, initial: [1], step: 0.01, count: 100)
    let got = trajectory[trajectory.count - 1][0]
    #expect(abs(got - 0.367_879_441_171_442_33) <= 1e-9, "e^{-1} at t = 1")
  }
}
