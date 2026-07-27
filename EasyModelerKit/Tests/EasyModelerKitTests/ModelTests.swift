import Foundation
import Testing

@testable import EasyModelerKit

/// Fences on the three models: that each right-hand side matches its definition
/// exactly, and that each obeys a real invariant of its dynamics (a conserved
/// quantity, a bounded attractor) rather than an invented magnitude.
struct ModelTests {
  // MARK: Right-hand sides match the tier-2 definitions

  @Test func lotkaVolterraDerivativesMatchDefinition() {
    // dx = A·x − B·x·y, dy = D·x·y − C·y with A=B=C=D=1 at (x,y)=(3,2).
    let got = LotkaVolterraModel().derivatives(0, [3, 2])
    #expect(got[0] == 3 - 3 * 2, "prey rate = A·x − B·x·y")
    #expect(got[1] == 3 * 2 - 2, "predator rate = D·x·y − C·y")
  }

  @Test func lorenzDerivativesMatchDefinition() {
    // The tier-2 example regime, at the initial state (1,1,1).
    let got = LorenzModel(sigma: 10, rho: 99.96, beta: 2).derivatives(0, [1, 1, 1])
    #expect(got[0] == 0, "σ(y−x) = 0 at x=y")
    #expect(isClose(got[1], 1 * (99.96 - 1) - 1), "x(ρ−z)−y")
    #expect(got[2] == 1 * 1 - 2 * 1, "xy − βz")
  }

  @Test func drivenLotkaVolterraDerivativesMatchDefinition() {
    // dx = A·food·x − B·x·y with food held at 0.5, at (x,y)=(3,2).
    let got = DrivenLotkaVolterraModel().derivatives(food: 0.5, 0, [3, 2])
    #expect(got[0] == 0.5 * 3 - 3 * 2, "prey rate scales with food")
    #expect(got[1] == 3 * 2 - 2, "predator rate is unforced")
  }

  // MARK: Invariants of the dynamics

  /// Lotka-Volterra conserves `V = D·x − C·ln x + B·y − A·ln y`. On the accurate
  /// solution it holds along the whole orbit, so `V` at every grid point equals
  /// its initial value — a genuine invariant, not a fitted number.
  @Test func lotkaVolterraConservesItsFirstIntegral() {
    func firstIntegral(_ state: [Double]) -> Double {
      state[0] - log(state[0]) + state[1] - log(state[1])
    }
    let initial = [3.0, 2.0]
    let trajectory = ODESolver.integrate(
      system: LotkaVolterraModel().system, initial: initial, step: 1.0, count: 20)
    let reference = firstIntegral(initial)
    for state in trajectory {
      #expect(
        abs(firstIntegral(state) - reference) <= 1e-5,
        "the LV first integral is conserved along the orbit")
    }
  }

  /// The classic-regime Lorenz attractor is bounded: from (1,1,1) every
  /// component stays finite and well inside a generous trapping box over a long
  /// run.
  @Test func classicLorenzStaysFiniteAndBounded() {
    let trajectory = ODESolver.integrate(
      system: LorenzModel().system, initial: [1, 1, 1], step: 0.01, count: 3000)
    #expect(trajectory.count == 3000, "one state recorded per step")
    for state in trajectory {
      #expect(state.count == 3, "the Lorenz state is three components")
      for value in state {
        #expect(value.isFinite, "no NaN/Inf escapes a bounded attractor")
        #expect(abs(value) < 200, "the classic attractor sits well inside |200|")
      }
    }
  }
}
