import Foundation
import Testing

@testable import EasyModelerKit

/// Fences on the "Build your own system" engine: that the parser honours the
/// usual precedence and associativity, that it evaluates the function set, that
/// it rejects bad input with the right error, and — the load-bearing ones — that
/// a system typed as text reproduces the hand-written models *bit for bit* when
/// it uses only `+ − × ÷`. Those built-in models are themselves parity-checked
/// against the Python engine, so matching them transitively pins the parser to
/// the tier-2 truth.
struct ExpressionTests {
  private func value(
    _ text: String, _ variables: [String: Double] = [:]
  ) throws -> Double {
    try Expression.parse(text).evaluate(
      variables: variables, functions: ExpressionSystem.functions)
  }

  // MARK: Precedence and associativity

  @Test func parsesArithmeticPrecedenceAndAssociativity() throws {
    #expect(try value("2 + 3 * 4") == 14)  // * before +
    #expect(try value("(2 + 3) * 4") == 20)  // parentheses override
    #expect(try value("10 - 2 - 3") == 5)  // - is left-associative
    #expect(try value("8 / 4 / 2") == 1)  // / is left-associative
    #expect(try value("2 ^ 3 ^ 2") == 512)  // ^ is right-associative (2^9)
    #expect(try value("-2 ^ 2") == -4)  // ^ binds tighter than a leading -
    #expect(try value("2 ^ -2") == 0.25)  // a unary exponent parses
    #expect(try value("1.5e2") == 150)  // scientific notation
  }

  // MARK: Functions and variables

  @Test func evaluatesFunctionsAndVariables() throws {
    let vars = ["x": 3.0, "k": 2.0]
    #expect(try value("exp(0)", vars) == 1)
    #expect(try value("pow(2, 10)", vars) == 1024)
    #expect(try value("k * x", vars) == 6)
    #expect(isClose(try value("ln(exp(1))", vars), 1))
    #expect(try value("abs(0 - x)", vars) == 3)
    #expect(try value("min(x, k)", vars) == 2)
    #expect(try value("max(x, k)", vars) == 3)
  }

  // MARK: Rejecting bad input

  @Test func rejectsMalformedExpressions() {
    #expect(throws: ExpressionError.self) { try Expression.parse("") }
    #expect(throws: ExpressionError.self) { try Expression.parse("   ") }
    #expect(throws: ExpressionError.self) { try Expression.parse("1 +") }
    #expect(throws: ExpressionError.self) { try Expression.parse("2 * (3") }
    #expect(throws: ExpressionError.self) { try Expression.parse("2 3") }
    #expect(throws: ExpressionError.self) { try Expression.parse("x @ y") }
  }

  @Test func buildRejectsUnknownNamesFunctionsAndArity() {
    #expect(throws: ExpressionError.unknownName("q")) {
      try ExpressionSystem.build(stateNames: ["x"], derivatives: ["q * x"], constants: [:])
    }
    #expect(throws: ExpressionError.unknownFunction("wobble")) {
      try ExpressionSystem.build(stateNames: ["x"], derivatives: ["wobble(x)"], constants: [:])
    }
    #expect(throws: ExpressionError.wrongArgumentCount(function: "pow", expected: 2, got: 1)) {
      try ExpressionSystem.build(stateNames: ["x"], derivatives: ["pow(x)"], constants: [:])
    }
    #expect(throws: ExpressionError.dimensionMismatch(states: 2, derivatives: 1)) {
      try ExpressionSystem.build(stateNames: ["x", "y"], derivatives: ["x"], constants: [:])
    }
    #expect(throws: ExpressionError.duplicateName("x")) {
      try ExpressionSystem.build(stateNames: ["x"], derivatives: ["x"], constants: ["x": 1])
    }
    #expect(throws: ExpressionError.forwardReference("g")) {
      try ExpressionSystem.build(
        stateNames: ["x"], derivatives: ["x"],
        helpers: [.init(name: "h", expression: "g"), .init(name: "g", expression: "1")],
        constants: [:])
    }
  }

  // MARK: Fidelity — typed equations match the hand-written models

  @Test func lotkaVolterraFromTextIsBitIdentical() throws {
    let text = try ExpressionSystem.build(
      stateNames: ["x", "y"],
      derivatives: ["a*x - b*x*y", "d*x*y - c*y"],
      constants: ["a": 1, "b": 1, "c": 1, "d": 1])
    let initial = [3.0, 2.0]
    let fromText = ODESolver.integrate(system: text.system, initial: initial, step: 1.0, count: 20)
    let hand = ODESolver.integrate(
      system: LotkaVolterraModel().system, initial: initial, step: 1.0, count: 20)
    #expect(
      maxAbsDifference(fromText, hand) == 0,
      "the parser reproduces the LV right-hand side bit for bit")
  }

  @Test func lorenzFromTextIsBitIdentical() throws {
    let text = try ExpressionSystem.build(
      stateNames: ["x", "y", "z"],
      derivatives: ["s*(y - x)", "x*(r - z) - y", "x*y - b*z"],
      constants: ["s": 10, "r": 28, "b": 8.0 / 3.0])
    let initial = [1.0, 1.0, 1.0]
    let fromText = ODESolver.integrate(
      system: text.system, initial: initial, step: 0.01, count: 2000)
    let hand = ODESolver.integrate(
      system: LorenzModel().system, initial: initial, step: 0.01, count: 2000)
    #expect(
      maxAbsDifference(fromText, hand) == 0,
      "chaos or not, the same arithmetic gives the same bits")
  }

  @Test func helpersMatchTheInlinedAndHandWrittenForms() throws {
    // A Gaussian-forced logistic decay — the shape of the Benthic model's growth
    // factor, exercising a helper, `exp`, and the shared evaluation order.
    let constants = ["k": 0.8, "m": 0.1, "c": 2.0]
    let withHelper = try ExpressionSystem.build(
      stateNames: ["B"],
      derivatives: ["k * g * B - m * B"],
      helpers: [.init(name: "g", expression: "exp(0 - c * B)")],
      constants: constants)
    let inlined = try ExpressionSystem.build(
      stateNames: ["B"],
      derivatives: ["k * exp(0 - c * B) * B - m * B"],
      constants: constants)
    let hand = ODESystem(dimension: 1) { _, state in
      let g = exp(0 - constants["c"]! * state[0])
      return [constants["k"]! * g * state[0] - constants["m"]! * state[0]]
    }
    let initial = [1.0]
    let a = ODESolver.integrate(system: withHelper.system, initial: initial, step: 0.5, count: 40)
    let b = ODESolver.integrate(system: inlined.system, initial: initial, step: 0.5, count: 40)
    let c = ODESolver.integrate(system: hand, initial: initial, step: 0.5, count: 40)
    #expect(maxAbsDifference(a, b) == 0, "a helper equals its inlined expansion")
    #expect(maxAbsDifference(a, c) == 0, "and both equal the hand-written closure")
  }

  @Test func helperValuesReconstructTheIntermediatesInOrder() throws {
    // The second helper reuses the first, so evaluation order matters.
    let system = try ExpressionSystem.build(
      stateNames: ["B"],
      derivatives: ["g2 - m * B"],
      helpers: [
        .init(name: "g1", expression: "exp(0 - c * B)"),
        .init(name: "g2", expression: "g1 * k"),
      ],
      constants: ["c": 2, "k": 3, "m": 0.1])
    #expect(system.helperNames == ["g1", "g2"])
    let values = system.helperValues(0, [1.5])
    let g1 = exp(0 - 2 * 1.5)
    #expect(isClose(values[0], g1))
    #expect(isClose(values[1], g1 * 3))
  }
}
