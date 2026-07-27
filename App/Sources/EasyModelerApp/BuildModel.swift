import EasyModelerKit
import Foundation
import Observation

/// One state equation the student is building: a name, its `d{name}/dt`
/// expression, and where it starts.
struct Equation: Identifiable {
  let id = UUID()
  var name: String
  var derivative: String
  var initial: Double
  var initialRange: ClosedRange<Double> = 0...20
}

/// A user-driven input the equations reference (temperature, salinity, depth) —
/// held still across a run and dialled with a slider.
struct InputVar: Identifiable {
  let id = UUID()
  var name: String
  var value: Double
  var range: ClosedRange<Double> = 0...20
}

/// A named coefficient — a fixed number in the equations, dialled with a slider.
struct Coefficient: Identifiable {
  let id = UUID()
  var name: String
  var value: Double
  var range: ClosedRange<Double> = 0...10
}

/// A named intermediate expression the equations reuse (like the Benthic model's
/// Gaussian salinity and temperature factors). Evaluated top to bottom each step.
struct HelperEq: Identifiable {
  let id = UUID()
  var name: String
  var expression: String
}

/// The "Build your own system" playground's observable state: the boxes
/// (equations and inputs), the coefficients, the helpers, and the trajectory
/// they produce. The Kit's `ExpressionSystem` parses and integrates them; this
/// is the view-facing editing surface and the sampled result the chart draws.
///
/// A run opens pre-loaded with the Benthic Ecology Model, ready to remix. Every
/// edit re-integrates; if the equations do not parse, the chart holds the last
/// good run and a plain-language message names the problem.
@Observable
final class BuildModel {
  /// Boxes and coefficients are capped so the system stays on rails; past this,
  /// the honest answer is the full Python engine (tier 2).
  static let maxBoxes = 6
  static let maxCoefficients = 15
  static let maxHelpers = 10

  var equations: [Equation] = []
  var inputs: [InputVar] = []
  var coefficients: [Coefficient] = []
  var helpers: [HelperEq] = []

  var horizon: Double = 30
  let horizonRange: ClosedRange<Double> = 5...730
  // Enough points for a smooth curve, few enough to keep the per-frame chart
  // redraw responsive while the playhead sweeps (a device-tuning knob).
  private let sampleCount = 400

  private(set) var samples: [BuildSample] = []
  private(set) var stateNames: [String] = []
  private(set) var helperSamples: [BuildSample] = []
  private(set) var builtHelperNames: [String] = []
  private(set) var parseError: String?
  private(set) var revision = 0
  private(set) var discreteEventCount = 0

  /// Whether the chart shows the helper values instead of the states. Helpers
  /// carry different units (the Benthic factors are 0…1), so they read on their
  /// own axis rather than overlaid on the states.
  var showingHelpers = false

  /// A box is a state equation or an input; together they share the 6-box budget.
  var boxCount: Int { equations.count + inputs.count }
  var canAddBox: Bool { boxCount < Self.maxBoxes }
  var canAddCoefficient: Bool { coefficients.count < Self.maxCoefficients }
  var canAddHelper: Bool { helpers.count < Self.maxHelpers }
  var canRemoveEquation: Bool { equations.count > 1 }

  /// There are built helpers to plot, so the States / Helpers toggle is offered.
  var hasHelpers: Bool { !builtHelperNames.isEmpty }
  /// The series names for the chart, honouring the toggle.
  var chartNames: [String] { showingHelpers && hasHelpers ? builtHelperNames : stateNames }
  /// The samples for the chart, honouring the toggle.
  var chartSamples: [BuildSample] { showingHelpers && hasHelpers ? helperSamples : samples }

  init() {
    loadBenthos()
  }

  // MARK: - Integration

  /// Rebuild the system from the current editor state and re-integrate. On a
  /// parse or wiring error, keep the last good curve and set `parseError`.
  func recompute() {
    guard !equations.isEmpty else {
      stateNames = []
      samples = []
      builtHelperNames = []
      helperSamples = []
      parseError = nil
      revision += 1
      return
    }

    let names = equations.map(\.name)
    let derivatives = equations.map(\.derivative)
    let helperList = helpers.map {
      ExpressionSystem.Helper(name: $0.name, expression: $0.expression)
    }
    var constants: [String: Double] = [:]
    for input in inputs { constants[input.name] = input.value }
    for coefficient in coefficients { constants[coefficient.name] = coefficient.value }

    do {
      let built = try ExpressionSystem.build(
        stateNames: names, derivatives: derivatives, helpers: helperList, constants: constants)
      let dt = horizon / Double(sampleCount)
      // A relaxed tolerance keeps the redraw instant while a slider is dragged.
      let control = StepControl(relative: 1e-7, absolute: 1e-10)
      let initial = equations.map(\.initial)
      let trajectory = ODESolver.integrate(
        system: built.system, initial: initial, step: dt, count: sampleCount, control: control)
      let full = [initial] + trajectory  // the engine excludes the initial state
      stateNames = names
      samples = full.enumerated().map { index, state in
        BuildSample(t: Double(index) * dt, values: state)
      }
      builtHelperNames = built.helperNames
      helperSamples = full.enumerated().map { index, state in
        let t = Double(index) * dt
        return BuildSample(t: t, values: built.helperValues(t, state))
      }
      parseError = nil
    } catch let error as ExpressionError {
      parseError = Self.message(for: error)
    } catch {
      parseError = "Something in the system did not add up."
    }
    revision += 1
  }

  /// The charted state at an arbitrary time (linear interpolation), for the
  /// playhead — honouring the States / Helpers toggle.
  func chartSample(at time: Double) -> BuildSample {
    interpolate(at: time, in: chartSamples)
  }

  private func interpolate(at time: Double, in series: [BuildSample]) -> BuildSample {
    guard series.count > 1 else { return series.first ?? BuildSample(t: 0, values: []) }
    let dt = horizon / Double(sampleCount)
    let position = min(max(time / dt, 0), Double(series.count - 1))
    let index = min(Int(position), series.count - 2)
    let blend = position - Double(index)
    let a = series[index]
    let b = series[index + 1]
    let values = zip(a.values, b.values).map { $0 + ($1 - $0) * blend }
    return BuildSample(t: time, values: values)
  }

  /// A one-line, plain-language read of the current run (of whichever series the
  /// chart is showing).
  var insight: String {
    if parseError != nil { return "Fix the highlighted equation to run your system." }
    guard let last = chartSamples.last, !last.values.isEmpty else {
      return "Add an equation to start your system."
    }
    let ends = zip(chartNames, last.values)
      .map { "\($0) ends near \(formatted($1))" }
      .joined(separator: ", ")
    return ends
  }

  private func formatted(_ value: Double) -> String {
    if !value.isFinite { return "off the chart" }
    return String(format: abs(value) >= 100 ? "%.0f" : "%.1f", value)
  }

  // MARK: - Editing

  func addEquation() {
    guard canAddBox else { return }
    equations.append(
      Equation(name: uniqueName("x", taken: allNames), derivative: "0", initial: 1))
    bump()
  }

  func removeEquation(_ id: UUID) {
    guard canRemoveEquation else { return }
    equations.removeAll { $0.id == id }
    bump()
  }

  func addInput() {
    guard canAddBox else { return }
    inputs.append(InputVar(name: uniqueName("in", taken: allNames), value: 1))
    bump()
  }

  func removeInput(_ id: UUID) {
    inputs.removeAll { $0.id == id }
    bump()
  }

  func addCoefficient() {
    guard canAddCoefficient else { return }
    coefficients.append(Coefficient(name: uniqueName("k", taken: allNames), value: 1))
    bump()
  }

  func removeCoefficient(_ id: UUID) {
    coefficients.removeAll { $0.id == id }
    bump()
  }

  func addHelper() {
    guard canAddHelper else { return }
    helpers.append(HelperEq(name: uniqueName("h", taken: allNames), expression: "0"))
    bump()
  }

  func removeHelper(_ id: UUID) {
    helpers.removeAll { $0.id == id }
    bump()
  }

  private func bump() {
    discreteEventCount += 1
    recompute()
  }

  private var allNames: Set<String> {
    Set(equations.map(\.name) + inputs.map(\.name) + coefficients.map(\.name) + helpers.map(\.name))
  }

  private func uniqueName(_ base: String, taken: Set<String>) -> String {
    if !taken.contains(base) { return base }
    var index = 2
    while taken.contains("\(base)\(index)") { index += 1 }
    return "\(base)\(index)"
  }

  // MARK: - Starter systems (remix these)

  func loadBenthos() {
    // The open estuary model, mirroring the phone's Estuary playground
    // (`OpenBenthosModel`): a benthos box B fed from a nutrient pool N, growth
    // shaped by Gaussian salinity and temperature optima and a Michaelis-Menten
    // food limit, all driven by two seasonal sine waves (temperature and
    // salinity) over the year. Nutrient flows in continuously (the foodInput
    // slider) and is buried out, so the system rides the seasons rather than
    // settling.
    equations = [
      Equation(
        name: "N", derivative: "foodInput - growth + recycle*death - burial*N",
        initial: 5, initialRange: 0...20),
      Equation(
        name: "B", derivative: "growth - death + recruitment",
        initial: 1, initialRange: 0...12),
    ]
    inputs = [
      InputVar(name: "foodInput", value: 3, range: 0...15),
      InputVar(name: "tempMean", value: 21, range: 0...35),
      InputVar(name: "salMean", value: 18, range: 0...40),
    ]
    coefficients = [
      Coefficient(name: "Kg", value: 8.78, range: 0...20),
      Coefficient(name: "Bcc", value: 12, range: 1...30),
      Coefficient(name: "Kgs", value: 2.94, range: 0.5...10),
      Coefficient(name: "Kgt", value: 5.48, range: 0.5...15),
      Coefficient(name: "Km", value: 0.23, range: 0...2),
      Coefficient(name: "Sopt", value: 13.47, range: 0...40),
      Coefficient(name: "Topt", value: 16.47, range: 0...35),
      Coefficient(name: "kN", value: 3, range: 0.1...15),
      Coefficient(name: "burial", value: 0.1, range: 0...1),
      Coefficient(name: "recycle", value: 0.5, range: 0...1),
      Coefficient(name: "recruitment", value: 0.02, range: 0...0.5),
      Coefficient(name: "tempAmp", value: 9, range: 0...20),
      Coefficient(name: "salAmp", value: 8, range: 0...20),
    ]
    helpers = [
      // The seasons: one wave a year, trough in winter (t=0), peak in summer.
      HelperEq(name: "season", expression: "-cos(6.28318530718 * t / 365)"),
      HelperEq(name: "temp", expression: "max(0, tempMean + tempAmp * season)"),
      HelperEq(name: "sal", expression: "max(0, salMean + salAmp * season)"),
      HelperEq(name: "gsal", expression: "exp(-pow(sal - Sopt, 2) / pow(2*Kgs, 2))"),
      HelperEq(name: "gtemp", expression: "exp(-pow(temp - Topt, 2) / pow(2*Kgt, 2))"),
      HelperEq(name: "foodLimit", expression: "N / (kN + N)"),
      HelperEq(name: "growth", expression: "Kg * gsal * gtemp * foodLimit * B * (1 - B/Bcc)"),
      HelperEq(name: "death", expression: "Km * B"),
    ]
    // A full year, so the seasonal bloom and summer crash both show.
    horizon = 365
    showingHelpers = false
    bump()
  }

  func loadPredatorPrey() {
    // Lotka-Volterra, the tier-2 example-1 regime: closed orbits.
    equations = [
      Equation(name: "prey", derivative: "a*prey - b*prey*pred", initial: 3, initialRange: 0...20),
      Equation(name: "pred", derivative: "d*prey*pred - c*pred", initial: 2, initialRange: 0...20),
    ]
    inputs = []
    coefficients = [
      Coefficient(name: "a", value: 1, range: 0...3),
      Coefficient(name: "b", value: 1, range: 0...3),
      Coefficient(name: "c", value: 1, range: 0...3),
      Coefficient(name: "d", value: 1, range: 0...3),
    ]
    helpers = []
    horizon = 20
    showingHelpers = false
    bump()
  }

  func loadLorenz() {
    // The Lorenz system, classic chaotic regime, as three lines over time.
    equations = [
      Equation(name: "x", derivative: "s*(y - x)", initial: 1, initialRange: -30...30),
      Equation(name: "y", derivative: "x*(r - z) - y", initial: 1, initialRange: -30...30),
      Equation(name: "z", derivative: "x*y - beta*z", initial: 1, initialRange: 0...50),
    ]
    inputs = []
    coefficients = [
      Coefficient(name: "s", value: 10, range: 0...20),
      Coefficient(name: "r", value: 28, range: 0...100),
      Coefficient(name: "beta", value: 8.0 / 3.0, range: 0...10),
    ]
    helpers = []
    horizon = 40
    showingHelpers = false
    bump()
  }

  func loadScratch() {
    // A blank slate: every section empty, built from scratch.
    equations = []
    inputs = []
    coefficients = []
    helpers = []
    horizon = 20
    showingHelpers = false
    bump()
  }

  // MARK: - Error copy

  /// Turn a Kit `ExpressionError` into a warm, plain-language line for the editor.
  static func message(for error: ExpressionError) -> String {
    switch error {
    case .empty:
      return "One equation is empty."
    case .unexpectedCharacter(let character):
      return "That character is not allowed: \(character)"
    case .malformedNumber(let text):
      return "That number does not look right: \(text)"
    case .unexpectedToken(let token):
      return "Something is out of place near \(token)."
    case .unexpectedEnd:
      return "An equation stops early. Is a bracket or a number missing?"
    case .unbalancedParentheses:
      return "Check the brackets. One does not have a partner."
    case .unknownName(let name):
      return "\(name) is not a box or coefficient yet. Add it, or fix the spelling."
    case .unknownFunction(let name):
      return "There is no function called \(name). Try exp, pow, sqrt, ln, sin, or cos."
    case .wrongArgumentCount(let function, let expected, let got):
      return "\(function) needs \(expected) value\(expected == 1 ? "" : "s"), but got \(got)."
    case .duplicateName(let name):
      return "Two things share the name \(name). Give each its own."
    case .dimensionMismatch:
      return "Every equation needs its own box."
    case .forwardReference(let name):
      return "\(name) is used before it is defined. Move it up the list."
    }
  }
}
