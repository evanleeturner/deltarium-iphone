#if canImport(Darwin)
  import Darwin
#elseif canImport(Glibc)
  import Glibc
#endif

/// A user-authored ODE system, wired from typed equations into the same
/// `ODESystem` the built-in models produce — the engine behind the "Build your
/// own system" playground.
///
/// You give it named state variables (each with a `dX/dt` expression), optional
/// named *helper* expressions (intermediate quantities the derivatives reuse,
/// like the Benthic model's Gaussian salinity and temperature factors), and a
/// table of constant values (the user's inputs and coefficients, which hold
/// still across a run). `build` parses every expression, checks that every name
/// and function resolves, and hands back an `ODESystem` ready for `ODESolver`.
///
/// Fidelity mirrors the built-in models. A system written with only `+ - * /`
/// integrates bit-identically across Linux and iOS, because the parser
/// reproduces the same operation order a hand-written right-hand side would use
/// (the Lotka-Volterra and Lorenz fences check exactly this). One that reaches
/// for `exp`/`pow` and the like carries the same tolerance contract as
/// `OpenBenthosModel`, since those library calls are not bit-portable.
public struct ExpressionSystem {
  /// The state variable names, in the order the solver's vector uses.
  public let stateNames: [String]
  /// The helper names, in evaluation order.
  public let helperNames: [String]
  /// The wired system, ready to hand to `ODESolver.integrate`.
  public let system: ODESystem
  /// The helper values at a given time and state — the same intermediates the
  /// right-hand side computes internally, exposed so a caller can plot them over
  /// a trajectory (their units differ from the states, so they read on their own
  /// axis). Returns one value per `helperNames`, in order.
  public let helperValues: (Double, [Double]) -> [Double]

  /// A named intermediate expression, evaluated (in list order) before the
  /// derivatives each step so several rates can share it.
  public struct Helper: Equatable, Sendable {
    public let name: String
    public let expression: String
    public init(name: String, expression: String) {
      self.name = name
      self.expression = expression
    }
  }

  /// The reserved name for the current time, always in scope in every expression.
  public static let timeName = "t"

  /// The math functions an expression may call. `log` is the natural logarithm,
  /// matching Python's `math.log` (the tier-2 engine's language); `log10` is base
  /// ten. Arguments and results are plain `Double`.
  public static let functions: MathFunctionTable = [
    "exp": (1, { exp($0[0]) }),
    "ln": (1, { log($0[0]) }),
    "log": (1, { log($0[0]) }),
    "log10": (1, { log10($0[0]) }),
    "sqrt": (1, { sqrt($0[0]) }),
    "abs": (1, { Swift.abs($0[0]) }),
    "pow": (2, { pow($0[0], $0[1]) }),
    "sin": (1, { sin($0[0]) }),
    "cos": (1, { cos($0[0]) }),
    "tan": (1, { tan($0[0]) }),
    "min": (2, { Swift.min($0[0], $0[1]) }),
    "max": (2, { Swift.max($0[0], $0[1]) }),
  ]

  public init(
    stateNames: [String], helperNames: [String], system: ODESystem,
    helperValues: @escaping (Double, [Double]) -> [Double]
  ) {
    self.stateNames = stateNames
    self.helperNames = helperNames
    self.system = system
    self.helperValues = helperValues
  }

  /// Parse and wire a system. Throws the first `ExpressionError` on a syntax
  /// slip, an unknown name or function, a bad arity, a duplicate name, a
  /// state/derivative count mismatch, or a helper used before it is defined.
  ///
  /// - Parameters:
  ///   - stateNames: the integrated variables, in solver order.
  ///   - derivatives: one `dX/dt` expression per state, same order.
  ///   - helpers: named intermediates, evaluated top to bottom before the
  ///     derivatives; each may reference states, constants, `t`, and the helpers
  ///     defined above it.
  ///   - constants: the inputs and coefficients merged — the values held fixed
  ///     across a run.
  public static func build(
    stateNames: [String],
    derivatives: [String],
    helpers: [Helper] = [],
    constants: [String: Double]
  ) throws -> ExpressionSystem {
    guard stateNames.count == derivatives.count else {
      throw ExpressionError.dimensionMismatch(
        states: stateNames.count, derivatives: derivatives.count)
    }

    // No two things may share a name, and nothing may shadow `t`.
    var seen = Set<String>()
    for name in stateNames + helpers.map(\.name) + Array(constants.keys) {
      guard name != timeName, seen.insert(name).inserted else {
        throw ExpressionError.duplicateName(name)
      }
    }

    // Parse everything up front so a syntax error surfaces before any wiring.
    let helperTrees = try helpers.map { try Expression.parse($0.expression) }
    let derivativeTrees = try derivatives.map { try Expression.parse($0) }

    // Names in scope: constants, states, and `t` are always available; each
    // helper joins the scope only for the helpers and derivatives after it.
    let baseScope = Set(constants.keys).union(stateNames).union([timeName])
    let helperNames = helpers.map(\.name)

    var scope = baseScope
    for (offset, tree) in helperTrees.enumerated() {
      let laterHelpers = Set(helperNames[(offset + 1)...])
      try validate(tree, scope: scope, laterHelpers: laterHelpers)
      scope.insert(helperNames[offset])
    }
    let fullScope = baseScope.union(helperNames)
    for tree in derivativeTrees {
      try validate(tree, scope: fullScope, laterHelpers: [])
    }

    // Wire the validated trees into a right-hand side. Constants are captured;
    // each step binds `t` and the state, evaluates the helpers in order, then
    // the derivatives.
    let names = stateNames
    let functionTable = functions

    // The shared setup: the variable table with the constants, `t`, and state
    // bound, and the helpers evaluated in order into it.
    func environment(_ t: Double, _ state: [Double]) -> [String: Double] {
      var variables = constants
      variables[timeName] = t
      for (i, name) in names.enumerated() {
        variables[name] = state[i]
      }
      for (offset, tree) in helperTrees.enumerated() {
        variables[helperNames[offset]] = tree.evaluate(
          variables: variables, functions: functionTable)
      }
      return variables
    }

    let system = ODESystem(dimension: stateNames.count) { t, state in
      let variables = environment(t, state)
      return derivativeTrees.map { $0.evaluate(variables: variables, functions: functionTable) }
    }

    let helperValues: (Double, [Double]) -> [Double] = { t, state in
      let variables = environment(t, state)
      return helperNames.map { variables[$0] ?? .nan }
    }

    return ExpressionSystem(
      stateNames: stateNames, helperNames: helperNames, system: system,
      helperValues: helperValues)
  }

  /// Check that every name in `tree` is in `scope` and every call is a known
  /// function with the right arity. A name that is a helper defined later reads
  /// as a `forwardReference`, not a plain `unknownName`.
  private static func validate(
    _ tree: Expression, scope: Set<String>, laterHelpers: Set<String>
  ) throws {
    for name in tree.referencedNames where !scope.contains(name) {
      if laterHelpers.contains(name) {
        throw ExpressionError.forwardReference(name)
      }
      throw ExpressionError.unknownName(name)
    }
    for call in tree.functionCalls {
      guard let function = functions[call.name] else {
        throw ExpressionError.unknownFunction(call.name)
      }
      guard function.arity == call.arity else {
        throw ExpressionError.wrongArgumentCount(
          function: call.name, expected: function.arity, got: call.arity)
      }
    }
  }
}
