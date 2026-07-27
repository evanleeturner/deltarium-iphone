import Testing

@testable import EasyModelerKit

/// Stepper-level fences for the Dormand–Prince integrator: exact closed forms
/// (not invented magnitudes), and dense-output consistency. Tolerances are the
/// solver's own accuracy, which the default control drives well below 1e-8.
struct DormandPrinceTests {
  /// Linear decay `y' = -y` has the closed form `y(t) = e^{-t}`. The adaptive
  /// solver tracks it to solver accuracy over a full unit of time.
  @Test func exponentialDecayMatchesClosedForm() {
    let decay = ODESystem(dimension: 1) { _, y in [-y[0]] }
    let got = DormandPrince.solve(decay, from: 0, to: 1, initial: [1])[0]
    let want = 0.367_879_441_171_442_33  // e^{-1}
    #expect(abs(got - want) <= 1e-9, "DOPRI5 tracks e^{-t} to solver accuracy")
  }

  /// The harmonic oscillator `x' = v, v' = -x` is a closed circle: from
  /// `[1, 0]` it returns to `[1, 0]` after one full period `2π`. A vector-valued
  /// closed-form fence that also checks the phase is right, not just the radius.
  @Test func harmonicOscillatorReturnsToStartAfterOnePeriod() {
    let oscillator = ODESystem(dimension: 2) { _, y in [y[1], -y[0]] }
    let period = 2 * 3.141_592_653_589_793_1
    let end = DormandPrince.solve(oscillator, from: 0, to: period, initial: [1, 0])
    #expect(abs(end[0] - 1) <= 1e-8, "position returns to 1 after one period")
    #expect(abs(end[1] - 0) <= 1e-8, "velocity returns to 0 after one period")
  }

  /// Dense output is exact at the step endpoints by construction: the first
  /// step's start sample is the initial state, the last step's end sample is the
  /// final state.
  @Test func denseOutputIsExactAtStepEndpoints() throws {
    let decay = ODESystem(dimension: 1) { _, y in [-y[0]] }
    let steps = DormandPrince.denseSolution(decay, from: 0, to: 1, initial: [1])
    let first = try #require(steps.first)
    let last = try #require(steps.last)
    #expect(first.sample(at: first.t0)[0] == 1, "theta=0 returns the start state exactly")
    #expect(
      last.sample(at: last.t0 + last.h)[0] == last.yEnd[0],
      "theta=1 returns the end state exactly")
  }

  /// The dense interpolant agrees with an independent re-integration to an
  /// interior time — the check that the continuous-extension coefficients are
  /// right (a wrong coefficient shows up as an O(1e-2) miss here).
  @Test func denseOutputMatchesReintegrationMidStep() throws {
    let decay = ODESystem(dimension: 1) { _, y in [-y[0]] }
    let steps = DormandPrince.denseSolution(decay, from: 0, to: 1, initial: [1])
    let target = 0.37
    let covering = try #require(steps.first { $0.t0 <= target && target <= $0.t0 + $0.h })
    let interpolated = covering.sample(at: target)[0]
    let reintegrated = DormandPrince.solve(decay, from: 0, to: target, initial: [1])[0]
    #expect(
      abs(interpolated - reintegrated) <= 1e-6,
      "dense output matches a fresh solve at the same time")
  }
}
