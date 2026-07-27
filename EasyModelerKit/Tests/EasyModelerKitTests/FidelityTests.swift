import Testing

@testable import EasyModelerKit

/// The fidelity oracle: the Swift engine (tier 1) reproduced against the frozen
/// Python `port_reference` fixtures (tier 2). The Swift solver is Dormand–Prince
/// and the Python solver is scipy's `vode`, so the contract is **agreement to
/// tolerance**, not the bit-exactness the Python port itself holds.
///
/// The tolerances are *measured*, not guessed: a faithful second implementation
/// of this exact algorithm (same tableau, control, and per-interval restart) was
/// run against the fixtures, giving the drift envelope
///
///   ex1 (LV)         whole run  4.9e-4
///   ex2 (Lorenz)     first 10   7.2e-4   → O(80) by the end (the butterfly)
///   ex3 (driven LV)  first 24   1.3e-4   → O(8) by the end (near-extinction)
///   benthos (open)   whole run  1.2e-4   (Swift DP vs vode over the seasonal year)
///   three-body (8)   first 100  2.5e-4   → grows to 5e-2 by two periods
///   lagrange (L4)    first 200  9.8e-6   → Jacobi constant holds to ~1e-15
///   decay (actinide) first 100  1.2e-5   → atoms conserved to ~1e-15; parents halve exactly
///
/// and the bounds below sit a few times above those, so a wrong tableau or a
/// mis-wired model (which miss by O(0.1+) even early) fails while an honest run
/// passes. Only the two *non-sensitive* windows get a matching-trajectory fence;
/// where the dynamics amplify tiny differences — Lorenz past the Lyapunov time,
/// driven-LV as the predator crashes toward extinction — the two solvers part
/// company on purpose, so those runs are fenced for boundedness and (for the
/// populations) positivity, not a late match.
///
/// The three-body figure-8 *inverts* the usual oracle relationship: the Swift DP
/// conserves energy to ~1e-10, far better than the vode reference (which drifts
/// ~4e-3), so their growing gap measures the *reference's* error, not the phone's.
/// So its match is fenced only early, and its real fence is a physics invariant —
/// the total mechanical energy, conserved to ~1e-10 on the figure-8 and through the
/// chaotic presets' softened close approaches — which the oracle plays no part in.
struct FidelityTests {
  private static let toleranceLotkaVolterra = 1.5e-3
  private static let earlyWindowLorenz = 10
  private static let toleranceLorenzEarly = 2e-3
  private static let earlyWindowDriven = 24
  private static let toleranceDrivenEarly = 1e-3
  private static let attractorBoxMargin = 1.0
  private static let positivityFloor = -1e-6
  private static let toleranceBenthos = 6e-4
  private static let stepsFigureEight = 1265  // two periods at dt = 0.01
  private static let earlyWindowThreeBody = 100
  private static let toleranceThreeBodyEarly = 6e-4
  private static let energyDriftFigureEight = 1e-7
  private static let periodStepsFigureEight = 633  // round(6.32591398 / 0.01)
  private static let returnGapFigureEight = 1.5e-2
  private static let energyDriftChaos = 5e-6
  private static let lagrangeKick = [0.0, 0.02, 0.005]
  private static let lagrangeSteps = 1257  // two synodic periods at dt = 0.01
  private static let equilibriumResidual = 1e-12
  private static let earlyWindowLagrange = 200
  private static let toleranceLagrangeEarly = 3e-5
  private static let jacobiDriftLagrange = 1e-10
  private static let stableRadius = 0.5
  private static let unstableEscape = 2.0
  private static let atomConservation = 1e-12
  private static let decaySteps = 1200
  private static let earlyWindowDecay = 100
  private static let toleranceDecayEarly = 5e-5
  private static let halfLifeTolerance = 1e-6
  private static let decayFloor = -1e-9

  /// Example 1 — undriven Lotka-Volterra, `[3, 2]`, dt = 1, 20 steps. Smooth and
  /// non-chaotic, so the whole run tracks the reference.
  @Test func lotkaVolterraTracksReference() throws {
    let reference = try Fixture.matrix("ex1")
    let computed = ODESolver.integrate(
      system: LotkaVolterraModel().system, initial: [3, 2], step: 1.0, count: 20)
    #expect(computed.count == reference.count, "same number of reported steps")
    #expect(
      maxAbsDifference(computed, reference) <= Self.toleranceLotkaVolterra,
      "the whole undriven-LV run tracks the Python reference")
  }

  /// Example 2 — Lorenz in the deep-chaos regime (σ=10, ρ=99.96, β=2), `[1,1,1]`,
  /// dt = 0.01, 3000 steps. The early window matches; the full run must only stay
  /// finite and inside the reference attractor's extent — past the Lyapunov time
  /// the trajectories diverge on purpose (the butterfly effect).
  @Test func lorenzMatchesEarlyThenStaysOnTheAttractor() throws {
    let reference = try Fixture.matrix("ex2")
    let computed = ODESolver.integrate(
      system: LorenzModel(sigma: 10, rho: 99.96, beta: 2).system,
      initial: [1, 1, 1], step: 0.01, count: 3000)
    #expect(computed.count == reference.count, "same number of reported steps")

    let earlyComputed = Array(computed.prefix(Self.earlyWindowLorenz))
    let earlyReference = Array(reference.prefix(Self.earlyWindowLorenz))
    #expect(
      maxAbsDifference(earlyComputed, earlyReference) <= Self.toleranceLorenzEarly,
      "Lorenz tracks the reference before the Lyapunov horizon")

    expectStaysWithinReferenceExtent(computed, reference: reference)
  }

  /// Example 3 — Lotka-Volterra driven by the monthly `food` series, `[3, 2]`,
  /// dt = 1, 241 steps. It tracks the reference over the first years; late, as the
  /// predator crashes toward extinction (a sensitive regime), the two solvers
  /// part company — so the whole run is fenced for non-negativity and bounded
  /// extent, not a matching trajectory.
  @Test func drivenLotkaVolterraTracksEarlyThenStaysBoundedAndPositive() throws {
    let reference = try Fixture.matrix("ex3")
    let food = try Fixture.vector("food")
    let computed = ODESolver.integrateForced(
      systemFor: DrivenLotkaVolterraModel().system(food:),
      initial: [3, 2], forcings: food, step: 1.0)
    #expect(computed.count == reference.count, "one row per monthly sample")

    let earlyComputed = Array(computed.prefix(Self.earlyWindowDriven))
    let earlyReference = Array(reference.prefix(Self.earlyWindowDriven))
    #expect(
      maxAbsDifference(earlyComputed, earlyReference) <= Self.toleranceDrivenEarly,
      "driven-LV tracks the reference over the first two years")

    for state in computed {
      #expect(
        state[0] >= Self.positivityFloor && state[1] >= Self.positivityFloor,
        "prey and predator stay non-negative")
    }
    expectStaysWithinReferenceExtent(computed, reference: reference)
  }

  /// The open benthos–nutrient playground model, driven by the seasonal
  /// temperature/salinity year, `[N, B] = [5, 1]`, dt = 1, 365 steps. Smooth and
  /// non-chaotic (unlike Lorenz) and bounded by burial and the logistic ceiling,
  /// so the whole run tracks the Python `vode` reference to tolerance.
  @Test func openBenthosTracksReference() throws {
    let forcing = try Fixture.matrix("benthos_forcing")  // rows of [temperature, salinity]
    let reference = try Fixture.matrix("benthos")  // rows of [N, B]
    let model = OpenBenthosModel()
    let computed = ODESolver.integrateForced(
      systemFor: { model.system(temperature: $0[0], salinity: $0[1]) },
      initial: [5, 1], forcings: forcing, step: 1.0)
    #expect(computed.count == reference.count, "one row per day of the year")
    #expect(
      maxAbsDifference(computed, reference) <= Self.toleranceBenthos,
      "the open-benthos run tracks the Python vode reference over the seasonal year")
  }

  /// The same run, checked for the qualitative behavior the phone teaches: the
  /// benthos stays non-negative and under carrying capacity, and it blooms in
  /// spring then crashes in the summer heat and salt (an open system that never
  /// settles), rather than any invented magnitude.
  @Test func openBenthosBloomsThenCrashes() throws {
    let forcing = try Fixture.matrix("benthos_forcing")
    let model = OpenBenthosModel()
    let computed = ODESolver.integrateForced(
      systemFor: { model.system(temperature: $0[0], salinity: $0[1]) },
      initial: [5, 1], forcings: forcing, step: 1.0)

    for state in computed {
      #expect(state[0] >= Self.positivityFloor, "nutrient stays non-negative")
      #expect(state[1] >= Self.positivityFloor, "biomass stays non-negative")
      #expect(
        state[1] <= model.carryingCapacity + 0.5, "biomass stays under carrying capacity")
    }
    let springBiomass = computed[89][1]  // ~day 90, near the salinity/temperature optimum
    let summerBiomass = computed[179][1]  // ~day 180, hot and salty — past the optimum
    #expect(
      springBiomass > summerBiomass,
      "the benthos blooms in spring and crashes in the summer heat and salt")
  }

  /// The figure-8 choreography — three equal masses on the canonical
  /// Chenciner–Montgomery orbit, `dt = 0.01`, two periods. Smooth and non-chaotic,
  /// so it tracks the vode reference early; the two part company only as the
  /// *reference* integrator loses accuracy over the long run, so the whole run is
  /// fenced for staying on the orbit, the early window for a match.
  @Test func figureEightTracksReferenceThenStaysBounded() throws {
    let reference = try Fixture.matrix("three_body")
    let config = ThreeBodyConfiguration.figureEight
    let computed = ODESolver.integrate(
      system: config.model.system, initial: config.initialState, step: 0.01,
      count: reference.count)
    #expect(computed.count == reference.count, "same number of reported steps")

    let earlyComputed = Array(computed.prefix(Self.earlyWindowThreeBody))
    let earlyReference = Array(reference.prefix(Self.earlyWindowThreeBody))
    #expect(
      maxAbsDifference(earlyComputed, earlyReference) <= Self.toleranceThreeBodyEarly,
      "the figure-8 tracks the reference before the vode integrator drifts")

    expectStaysWithinReferenceExtent(computed, reference: reference)
  }

  /// The physics fence, and the strongest one: a gravitational system conserves its
  /// total mechanical energy, and a non-symplectic solver lets it drift only slowly.
  /// The figure-8 run holds energy to ~1e-10 — a wrong force law would drift by
  /// O(0.1+) — so this ties the Swift model to the real dynamics with no oracle.
  @Test func figureEightConservesEnergy() throws {
    let config = ThreeBodyConfiguration.figureEight
    let model = config.model
    let computed = ODESolver.integrate(
      system: model.system, initial: config.initialState, step: 0.01,
      count: Self.stepsFigureEight)
    let energy0 = model.totalEnergy(config.initialState)
    let drift =
      ([config.initialState] + computed)
      .map { abs(model.totalEnergy($0) - energy0) }
      .max() ?? 0
    #expect(drift <= Self.energyDriftFigureEight, "the figure-8 conserves its energy")
  }

  /// The choreography is periodic: after one period the three bodies return to
  /// where they began (the closed 8). The gap is small but not zero — the published
  /// initial data has finitely many digits — so the fence is loose, but a broken
  /// orbit would miss it by an order of magnitude.
  @Test func figureEightReturnsAfterOnePeriod() throws {
    let config = ThreeBodyConfiguration.figureEight
    let computed = ODESolver.integrate(
      system: config.model.system, initial: config.initialState, step: 0.01,
      count: Self.periodStepsFigureEight)
    let atPeriod = computed[Self.periodStepsFigureEight - 1]
    let gap = zip(atPeriod, config.initialState).map { abs($0 - $1) }.max() ?? 0
    #expect(gap <= Self.returnGapFigureEight, "the figure-8 closes after one period")
  }

  /// Even in the chaotic regimes the presets actually use — the Pythagorean
  /// binary-and-ejection scramble and the out-of-plane tangle — energy stays
  /// conserved and nothing escapes to NaN through the softened close approaches.
  /// Chaos makes the trajectory unpredictable, not the physics unphysical.
  @Test func chaoticRunsConserveEnergy() throws {
    for config in [ThreeBodyConfiguration.pythagorean, ThreeBodyConfiguration.tangle] {
      let model = config.model
      let computed = ODESolver.integrate(
        system: model.system, initial: config.initialState, step: 0.01, count: 1200)
      let energy0 = model.totalEnergy(config.initialState)
      for state in computed {
        for value in state {
          #expect(value.isFinite, "the softened close approaches never blow up")
        }
        #expect(
          abs(model.totalEnergy(state) - energy0) <= Self.energyDriftChaos,
          "energy holds through the chaotic scramble")
      }
    }
  }

  /// The five Lagrange points are true equilibria: a satellite placed exactly at
  /// one with zero velocity feels no net force. The residual acceleration reaches
  /// machine precision, which validates both the CR3BP model and the Newton solve
  /// for the collinear points in one check.
  @Test func lagrangePointsAreEquilibria() {
    let model = RestrictedThreeBodyModel()
    for point in EarthMoonSystem.lagrangePoints {
      let derivative = model.derivatives(0, point.position + [0, 0, 0])
      let acceleration =
        (derivative[3] * derivative[3] + derivative[4] * derivative[4]
        + derivative[5] * derivative[5]).squareRoot()
      #expect(
        acceleration < Self.equilibriumResidual,
        "\(point.name) is a force-free equilibrium of the rotating frame")
    }
  }

  /// A satellite launched from L4 with a small kick librates in a bounded loop
  /// around the point, `dt = 0.01`, two synodic periods. Smooth and stable, so it
  /// tracks the vode reference early; the two part company only as the *reference*
  /// integrator drifts, so the whole run is fenced for staying bounded, the early
  /// window for a match.
  @Test func l4LaunchTracksReferenceThenStaysBounded() throws {
    let reference = try Fixture.matrix("lagrange")
    let model = RestrictedThreeBodyModel()
    let initial = EarthMoonSystem.launchState(at: lagrangePoint("L4"), deltaV: Self.lagrangeKick)
    let computed = ODESolver.integrate(
      system: model.system, initial: initial, step: 0.01, count: reference.count)
    #expect(computed.count == reference.count, "same number of reported steps")

    let earlyComputed = Array(computed.prefix(Self.earlyWindowLagrange))
    let earlyReference = Array(reference.prefix(Self.earlyWindowLagrange))
    #expect(
      maxAbsDifference(earlyComputed, earlyReference) <= Self.toleranceLagrangeEarly,
      "the L4 libration tracks the reference before the vode integrator drifts")

    expectStaysWithinReferenceExtent(computed, reference: reference)
  }

  /// The physics fence: the rotating frame conserves the Jacobi constant, and the
  /// Swift solver holds it to ~1e-15 on the bounded L4 libration — a wrong force law
  /// would drift by orders of magnitude, so this ties the model to the real
  /// dynamics with no oracle.
  @Test func l4LaunchConservesJacobiConstant() {
    let model = RestrictedThreeBodyModel()
    let initial = EarthMoonSystem.launchState(at: lagrangePoint("L4"), deltaV: Self.lagrangeKick)
    let computed = ODESolver.integrate(
      system: model.system, initial: initial, step: 0.01, count: Self.lagrangeSteps)
    let c0 = model.jacobiConstant(initial)
    let drift =
      ([initial] + computed)
      .map { abs(model.jacobiConstant($0) - c0) }
      .max() ?? 0
    #expect(drift <= Self.jacobiDriftLagrange, "the L4 libration conserves the Jacobi constant")
  }

  /// The lesson, fenced: given the same launch kick, the stable equilateral points
  /// L4 and L5 hold station (they stay within a small radius), while the collinear
  /// L2 is unstable and the kick sends it far away. L1 and L3 also leave their
  /// points but into the bounded interior rather than escaping, so they are shown
  /// in the app but not fenced on distance here — L2 is the clean, unambiguous case.
  @Test func stableLagrangePointsHoldUnstableOnesLeave() {
    #expect(maxExcursion(from: "L4") < Self.stableRadius, "L4 holds station under a kick")
    #expect(maxExcursion(from: "L5") < Self.stableRadius, "L5 holds station under a kick")
    #expect(
      maxExcursion(from: "L2") > Self.unstableEscape, "L2 is unstable — the kick sends it away")
  }

  /// The largest distance a kicked satellite reaches from its Lagrange point over
  /// the run — small for a stable point, large for an unstable one.
  private func maxExcursion(from name: String) -> Double {
    let model = RestrictedThreeBodyModel()
    let point = lagrangePoint(name)
    let initial = EarthMoonSystem.launchState(at: point, deltaV: Self.lagrangeKick)
    let trajectory = ODESolver.integrate(
      system: model.system, initial: initial, step: 0.01, count: Self.lagrangeSteps)
    return ([initial] + trajectory).map { state in
      let dx = state[0] - point.position[0]
      let dy = state[1] - point.position[1]
      let dz = state[2] - point.position[2]
      return (dx * dx + dy * dy + dz * dz).squareRoot()
    }.max() ?? 0
  }

  private func lagrangePoint(_ name: String) -> LagrangePoint {
    for point in EarthMoonSystem.lagrangePoints where point.name == name {
      return point
    }
    return EarthMoonSystem.lagrangePoints[0]
  }

  /// Radioactive decay transforms nuclei, it does not destroy them: the total
  /// number of atoms across a chain (parents, daughters, and the stable end) is
  /// conserved. Every source's chains hold it to machine precision — the physics
  /// fence, and it validates the chain wiring (each `-λN` out lands as a `+λN` in).
  @Test func decayChainsConserveAtoms() {
    for source in RadiationSource.all {
      for chain in source.chains {
        let dt = source.horizonYears / Double(Self.decaySteps)
        let computed = ODESolver.integrate(
          system: chain.model.system, initial: chain.initialAmounts, step: dt,
          count: Self.decaySteps)
        let atoms0 = chain.initialAmounts.reduce(0, +)
        let drift =
          ([chain.initialAmounts] + computed)
          .map { abs($0.reduce(0, +) - atoms0) }
          .max() ?? 0
        #expect(
          drift <= Self.atomConservation,
          "the \(chain.members[0].name) chain conserves its atoms")
        for state in computed {
          for amount in state {
            #expect(amount >= Self.decayFloor, "amounts stay non-negative")
          }
        }
      }
    }
  }

  /// The defining property of radioactivity: after one half-life, exactly half the
  /// parent nuclei remain. Each source's parents halve to within a hair of 0.5 —
  /// the closed-form `e^{-ln2}` is the exact oracle, no fixture needed.
  @Test func decayParentsHalveEachHalfLife() {
    for source in RadiationSource.all {
      for chain in source.chains {
        let halfLife = chain.members[0].halfLifeYears
        let computed = ODESolver.integrate(
          system: chain.model.system, initial: chain.initialAmounts, step: halfLife, count: 1)
        #expect(
          abs(computed[0][0] - 0.5) <= Self.halfLifeTolerance,
          "\(chain.members[0].name) halves after one half-life")
      }
    }
  }

  /// The elaborate chain — the H-bomb plutonium/uranium actinide series, five
  /// members over 250,000 years. Smooth and non-chaotic, so it tracks the vode
  /// reference early; the two part company only as the reference integrator drifts.
  /// The whole run conserves atoms, and the daughters grow in as the parents decay.
  @Test func actinideChainTracksReferenceAndConservesAtoms() throws {
    let reference = try Fixture.matrix("decay")
    let chain = RadiationSource.hBomb.chains[0]
    let dt = RadiationSource.hBomb.horizonYears / Double(reference.count)
    let computed = ODESolver.integrate(
      system: chain.model.system, initial: chain.initialAmounts, step: dt,
      count: reference.count)
    #expect(computed.count == reference.count, "same number of reported steps")

    let earlyComputed = Array(computed.prefix(Self.earlyWindowDecay))
    let earlyReference = Array(reference.prefix(Self.earlyWindowDecay))
    #expect(
      maxAbsDifference(earlyComputed, earlyReference) <= Self.toleranceDecayEarly,
      "the actinide chain tracks the reference before the vode integrator drifts")

    let atoms0 = chain.initialAmounts.reduce(0, +)
    for state in computed {
      #expect(abs(state.reduce(0, +) - atoms0) <= Self.atomConservation, "atoms conserved")
    }
  }

  /// Assert every state stays finite and inside the reference trajectory's
  /// per-component extent, widened by `attractorBoxMargin` — an oracle-derived
  /// box, never an invented magnitude.
  private func expectStaysWithinReferenceExtent(
    _ computed: [[Double]], reference: [[Double]]
  ) {
    let bounds = componentBounds(reference)
    for state in computed {
      for i in state.indices {
        #expect(state[i].isFinite, "no NaN/Inf escapes the bounded dynamics")
        let range = bounds[i].max - bounds[i].min
        let low = bounds[i].min - Self.attractorBoxMargin * range
        let high = bounds[i].max + Self.attractorBoxMargin * range
        #expect(state[i] >= low && state[i] <= high, "the run stays within the reference extent")
      }
    }
  }
}
