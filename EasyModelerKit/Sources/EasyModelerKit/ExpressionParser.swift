#if canImport(Darwin)
  import Darwin
#elseif canImport(Glibc)
  import Glibc
#endif

/// Errors from parsing or wiring a user-typed expression. They are surfaced
/// verbatim to the editor, so a slip reads as a clear message rather than a
/// silent wrong run.
public enum ExpressionError: Error, Equatable, Sendable {
  /// The text held no expression (empty or all whitespace).
  case empty
  /// A character the lexer does not recognise (e.g. `@`, `$`).
  case unexpectedCharacter(Character)
  /// A number literal that would not parse (e.g. `1.2.3`, `1e`).
  case malformedNumber(String)
  /// A token turned up where the grammar did not expect one.
  case unexpectedToken(String)
  /// The expression ended mid-way (a dangling operator, an unclosed call).
  case unexpectedEnd
  /// A `(` with no matching `)`.
  case unbalancedParentheses
  /// An identifier that is neither a state, an input, a coefficient, an
  /// in-scope helper, nor `t`.
  case unknownName(String)
  /// A call to a function the engine does not provide.
  case unknownFunction(String)
  /// A known function called with the wrong number of arguments.
  case wrongArgumentCount(function: String, expected: Int, got: Int)
  /// Two boxes, coefficients, or helpers share a name (or one shadows `t`).
  case duplicateName(String)
  /// The state count and the derivative count disagree.
  case dimensionMismatch(states: Int, derivatives: Int)
  /// A helper referenced itself or a later helper (only earlier ones are in scope).
  case forwardReference(String)
}

/// A function table: name to its arity and implementation. The evaluator and
/// `ExpressionSystem.functions` share this shape.
public typealias MathFunctionTable = [String: (arity: Int, apply: @Sendable ([Double]) -> Double)]

/// A parsed arithmetic expression over named variables — the small language the
/// "Build your own system" editor speaks.
///
/// Grammar (ordinary precedence; the operators are the ASCII `+ - * / ^`):
///
///     expression -> term  (('+' | '-') term)*
///     term       -> unary (('*' | '/') unary)*
///     unary      -> ('+' | '-') unary | power
///     power      -> primary ('^' unary)?          // right-associative
///     primary    -> number | name | name '(' args ')' | '(' expression ')'
///
/// Power binds tighter than a leading minus, so `-x^2` reads as `-(x^2)`, the
/// usual mathematical convention, and `2^-3` is well-formed. Identifiers are
/// case-sensitive (`Kg` is not `kg`), and there is no implicit multiplication —
/// write `2*x`, not `2x`.
public indirect enum Expression: Equatable, Sendable {
  case number(Double)
  case name(String)
  case negate(Expression)
  case add(Expression, Expression)
  case subtract(Expression, Expression)
  case multiply(Expression, Expression)
  case divide(Expression, Expression)
  case power(Expression, Expression)
  case call(String, [Expression])

  /// Parse `text` into an expression tree, or throw the first `ExpressionError`.
  public static func parse(_ text: String) throws -> Expression {
    let tokens = try tokenize(text)
    guard !tokens.isEmpty else { throw ExpressionError.empty }
    var parser = Parser(tokens: tokens)
    let expression = try parser.parseExpression()
    try parser.expectEnd()
    return expression
  }

  /// Evaluate against a variable table and a function table. Names and functions
  /// are assumed already validated (see `ExpressionSystem.build`); an unresolved
  /// name evaluates to NaN rather than trapping, so a live run degrades to a
  /// visible blow-up on the chart instead of a crash.
  public func evaluate(variables: [String: Double], functions: MathFunctionTable) -> Double {
    switch self {
    case .number(let value):
      return value
    case .name(let name):
      return variables[name] ?? .nan
    case .negate(let a):
      return -a.evaluate(variables: variables, functions: functions)
    case .add(let a, let b):
      return a.evaluate(variables: variables, functions: functions)
        + b.evaluate(variables: variables, functions: functions)
    case .subtract(let a, let b):
      return a.evaluate(variables: variables, functions: functions)
        - b.evaluate(variables: variables, functions: functions)
    case .multiply(let a, let b):
      return a.evaluate(variables: variables, functions: functions)
        * b.evaluate(variables: variables, functions: functions)
    case .divide(let a, let b):
      return a.evaluate(variables: variables, functions: functions)
        / b.evaluate(variables: variables, functions: functions)
    case .power(let a, let b):
      return pow(
        a.evaluate(variables: variables, functions: functions),
        b.evaluate(variables: variables, functions: functions))
    case .call(let name, let args):
      let values = args.map { $0.evaluate(variables: variables, functions: functions) }
      guard let function = functions[name] else { return .nan }
      return function.apply(values)
    }
  }

  /// Every bare identifier the tree references (variables, not function names).
  var referencedNames: Set<String> {
    switch self {
    case .number:
      return []
    case .name(let name):
      return [name]
    case .negate(let a):
      return a.referencedNames
    case .add(let a, let b), .subtract(let a, let b), .multiply(let a, let b),
      .divide(let a, let b), .power(let a, let b):
      return a.referencedNames.union(b.referencedNames)
    case .call(_, let args):
      return args.reduce(into: Set<String>()) { $0.formUnion($1.referencedNames) }
    }
  }

  /// Every function call in the tree, as `(name, argument count)`, for arity checks.
  var functionCalls: [(name: String, arity: Int)] {
    switch self {
    case .number, .name:
      return []
    case .negate(let a):
      return a.functionCalls
    case .add(let a, let b), .subtract(let a, let b), .multiply(let a, let b),
      .divide(let a, let b), .power(let a, let b):
      return a.functionCalls + b.functionCalls
    case .call(let name, let args):
      return [(name, args.count)] + args.flatMap { $0.functionCalls }
    }
  }
}

// MARK: - Lexer

private enum Token: Equatable {
  case number(Double)
  case name(String)
  case plus, minus, star, slash, caret
  case leftParen, rightParen, comma
}

private func tokenize(_ text: String) throws -> [Token] {
  var tokens: [Token] = []
  let characters = Array(text)
  var i = 0
  while i < characters.count {
    let c = characters[i]
    if c == " " || c == "\t" || c == "\n" || c == "\r" {
      i += 1
      continue
    }
    switch c {
    case "+": tokens.append(.plus); i += 1
    case "-": tokens.append(.minus); i += 1
    case "*": tokens.append(.star); i += 1
    case "/": tokens.append(.slash); i += 1
    case "^": tokens.append(.caret); i += 1
    case "(": tokens.append(.leftParen); i += 1
    case ")": tokens.append(.rightParen); i += 1
    case ",": tokens.append(.comma); i += 1
    default:
      if c.isNumber || c == "." {
        var literal = ""
        while i < characters.count {
          let d = characters[i]
          if d.isNumber || d == "." {
            literal.append(d)
            i += 1
          } else if d == "e" || d == "E" {
            literal.append(d)
            i += 1
            if i < characters.count, characters[i] == "+" || characters[i] == "-" {
              literal.append(characters[i])
              i += 1
            }
          } else {
            break
          }
        }
        guard let value = Double(literal) else {
          throw ExpressionError.malformedNumber(literal)
        }
        tokens.append(.number(value))
      } else if c.isLetter || c == "_" {
        var identifier = ""
        while i < characters.count {
          let d = characters[i]
          if d.isLetter || d.isNumber || d == "_" {
            identifier.append(d)
            i += 1
          } else {
            break
          }
        }
        tokens.append(.name(identifier))
      } else {
        throw ExpressionError.unexpectedCharacter(c)
      }
    }
  }
  return tokens
}

// MARK: - Parser

private struct Parser {
  let tokens: [Token]
  var index = 0

  var current: Token? { index < tokens.count ? tokens[index] : nil }

  mutating func expectEnd() throws {
    if index != tokens.count {
      throw ExpressionError.unexpectedToken(describe(tokens[index]))
    }
  }

  mutating func parseExpression() throws -> Expression {
    var left = try parseTerm()
    while let token = current, token == .plus || token == .minus {
      index += 1
      let right = try parseTerm()
      left = token == .plus ? .add(left, right) : .subtract(left, right)
    }
    return left
  }

  mutating func parseTerm() throws -> Expression {
    var left = try parseUnary()
    while let token = current, token == .star || token == .slash {
      index += 1
      let right = try parseUnary()
      left = token == .star ? .multiply(left, right) : .divide(left, right)
    }
    return left
  }

  mutating func parseUnary() throws -> Expression {
    if let token = current, token == .plus || token == .minus {
      index += 1
      let operand = try parseUnary()
      return token == .minus ? .negate(operand) : operand
    }
    return try parsePower()
  }

  mutating func parsePower() throws -> Expression {
    let base = try parsePrimary()
    if current == .caret {
      index += 1
      // Right-associative, and the exponent is a unary so `2^-3` parses.
      let exponent = try parseUnary()
      return .power(base, exponent)
    }
    return base
  }

  mutating func parsePrimary() throws -> Expression {
    guard let token = current else { throw ExpressionError.unexpectedEnd }
    switch token {
    case .number(let value):
      index += 1
      return .number(value)
    case .name(let name):
      index += 1
      guard current == .leftParen else { return .name(name) }
      index += 1
      var arguments: [Expression] = []
      if current != .rightParen {
        arguments.append(try parseExpression())
        while current == .comma {
          index += 1
          arguments.append(try parseExpression())
        }
      }
      guard current == .rightParen else { throw ExpressionError.unbalancedParentheses }
      index += 1
      return .call(name, arguments)
    case .leftParen:
      index += 1
      let inner = try parseExpression()
      guard current == .rightParen else { throw ExpressionError.unbalancedParentheses }
      index += 1
      return inner
    default:
      throw ExpressionError.unexpectedToken(describe(token))
    }
  }
}

private func describe(_ token: Token) -> String {
  switch token {
  case .number(let value): return "\(value)"
  case .name(let name): return name
  case .plus: return "+"
  case .minus: return "-"
  case .star: return "*"
  case .slash: return "/"
  case .caret: return "^"
  case .leftParen: return "("
  case .rightParen: return ")"
  case .comma: return ","
  }
}
