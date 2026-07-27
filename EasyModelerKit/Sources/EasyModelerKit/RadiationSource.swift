/// One nuclide in a decay chain: its name, half-life (years; `.infinity` for a
/// stable end), and an *activity weight* that folds in any ultra-fast daughters it
/// carries in secular equilibrium (Cs-137 carries Ba-137m, Sr-90 carries Y-90,
/// U-235 carries Th-231, Ac-227 carries its short-lived tail down to lead).
public struct Nuclide: Sendable {
  public let name: String
  public let halfLifeYears: Double
  public let activityWeight: Double

  public init(name: String, halfLifeYears: Double, activityWeight: Double) {
    self.name = name
    self.halfLifeYears = halfLifeYears
    self.activityWeight = activityWeight
  }

  /// The decay constant `λ = ln2 / half-life` (0 for a stable nuclide).
  public var decayConstant: Double {
    halfLifeYears.isFinite ? RadiationSource.ln2 / halfLifeYears : 0
  }
}

/// A single decay chain — an ordered list of nuclides, parent first, stable end
/// last. Provides the model, the initial state, and the chain's total activity.
public struct DecayChain: Sendable {
  public let members: [Nuclide]

  public init(_ members: [Nuclide]) {
    self.members = members
  }

  public var decayConstants: [Double] { members.map(\.decayConstant) }

  public var model: DecayChainModel { DecayChainModel(decayConstants: decayConstants) }

  /// One unit of the parent nuclide; the daughters start at 0 and grow in as the
  /// parent decays. The app normalizes the resulting activity curve for display, so
  /// this is just a clean unit amount.
  public var initialAmounts: [Double] {
    var amounts = [Double](repeating: 0, count: members.count)
    amounts[0] = 1.0
    return amounts
  }

  /// The chain's total activity `Σ weight_i · λ_i · N_i` — what a detector reads,
  /// counting every radioactive member (and its equilibrium daughters via the weight).
  public func activity(_ state: [Double]) -> Double {
    var total = 0.0
    for i in members.indices {
      total += members[i].activityWeight * members[i].decayConstant * state[i]
    }
    return total
  }
}

/// A radiation source: the decay chains it releases and the time window over which
/// its dominant isotopes play out. These are the shared physics constants for the
/// app and the fidelity test, and they must equal the tier-2 oracle
/// `easymodeler/examples/decay.py`.
public struct RadiationSource: Sendable {
  public let name: String
  public let chains: [DecayChain]
  /// The display/integration window, in years, sized to the source's dominant
  /// half-lives (the accident lingers for centuries; carbon and the bomb for
  /// tens to hundreds of thousands of years).
  public let horizonYears: Double

  public init(name: String, chains: [DecayChain], horizonYears: Double) {
    self.name = name
    self.chains = chains
    self.horizonYears = horizonYears
  }

  static let ln2 = 0.6931471805599453
  static let day = 1.0 / 365.25  // a day, in years

  private static func stable(_ name: String) -> Nuclide {
    Nuclide(name: name, halfLifeYears: .infinity, activityWeight: 0)
  }

  /// Carbon-14 — natural, used for dating. Decays straight to stable nitrogen, the
  /// simple case: it really does just fade away, halving every 5,730 years.
  public static let carbon14 = RadiationSource(
    name: "Carbon-14",
    chains: [
      DecayChain([
        Nuclide(name: "C-14", halfLifeYears: 5730, activityWeight: 1),
        stable("N-14"),
      ])
    ],
    horizonYears: 40000)

  /// Reactor-accident fallout — the three signature fission products. Iodine is
  /// intense but gone in weeks; caesium (through its barium gamma) and strontium
  /// (with its yttrium daughter) linger for centuries.
  public static let accident = RadiationSource(
    name: "Accident",
    chains: [
      DecayChain([
        Nuclide(name: "I-131", halfLifeYears: 8.0197 * day, activityWeight: 1),
        stable("Xe-131"),
      ]),
      DecayChain([
        Nuclide(name: "Cs-137", halfLifeYears: 30.17, activityWeight: 1.95),
        stable("Ba-137"),
      ]),
      DecayChain([
        Nuclide(name: "Sr-90", halfLifeYears: 28.79, activityWeight: 2),
        stable("Zr-90"),
      ]),
    ],
    horizonYears: 300)

  /// H-bomb fallout — plutonium decays into a uranium series, each member
  /// radioactive in turn, so it stays radioactive for hundreds of thousands of years
  /// and leaves a faint uranium floor that never fully goes away.
  public static let hBomb = RadiationSource(
    name: "H-bomb",
    chains: [
      DecayChain([
        Nuclide(name: "Pu-239", halfLifeYears: 24110, activityWeight: 1),
        Nuclide(name: "U-235", halfLifeYears: 7.038e8, activityWeight: 2),
        Nuclide(name: "Pa-231", halfLifeYears: 32760, activityWeight: 1),
        Nuclide(name: "Ac-227", halfLifeYears: 21.772, activityWeight: 8),
        stable("Pb-207"),
      ])
    ],
    horizonYears: 250000)

  /// The three sources, in the order the app presents them.
  public static let all = [carbon14, accident, hBomb]
}
