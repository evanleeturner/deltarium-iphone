import Foundation
import Testing

@testable import EasyModelerKit

/// Fences on the relativistic journey: that the closed-form trip figures match
/// published relativistic-rocket results, that the integrated trajectory lands
/// exactly on that closed form, and that the ship's clock always lags Earth's.
struct RelativityTests {
  private var oneG: Double { RelativisticJourneyModel.naturalAccelerationPerG }

  @Test func oneGIsAboutOneLightYearPerYearSquared() {
    #expect(abs(RelativisticJourneyModel.naturalAccelerationPerG - 1.0323) < 1e-3)
  }

  @Test func alphaCentauriMatchesPublishedFigures() {
    // 1 g flip-and-burn to Alpha Centauri (4.37 ly): ~6.0 Earth-yr, ~3.6 ship-yr.
    let model = RelativisticJourneyModel(acceleration: oneG, distance: 4.37)
    #expect(abs(model.earthTimeTotal - 6.003) < 0.02)
    #expect(abs(model.shipTimeTotal - 3.582) < 0.02)
    #expect(abs(model.peakBeta - 0.9517) < 1e-3)
    #expect(model.peakGamma > 3 && model.peakGamma < 3.5)
  }

  @Test func andromedaCrossesInThirtyShipYears() {
    // The famous result: ~28.6 ship-years to Andromeda while millions pass on Earth.
    let model = RelativisticJourneyModel(acceleration: oneG, distance: 2.537e6)
    #expect(abs(model.shipTimeTotal - 28.63) < 0.1)
    #expect(model.earthTimeTotal > 2.5e6)
    #expect(model.massRatio.isFinite, "the exp form does not overflow")
  }

  @Test func journeyEndpointMatchesTheClosedForm() {
    let model = RelativisticJourneyModel(acceleration: oneG, distance: 4.37)
    let steps = 400
    let dt = model.shipTimeTotal / Double(steps)
    let trajectory = ODESolver.integrate(
      system: model.system, initial: [0, 0], step: dt, count: steps)
    let end = trajectory.last!
    #expect(abs(end[0] - model.distance) < 1e-3, "arrives at the destination, at rest")
    #expect(abs(end[1] - model.earthTimeTotal) < 1e-2, "Earth clock matches the closed form")
  }

  @Test func shipClockAlwaysLagsEarthClock() {
    let model = RelativisticJourneyModel(acceleration: oneG, distance: 11.9)
    let steps = 400
    let dt = model.shipTimeTotal / Double(steps)
    let trajectory = ODESolver.integrate(
      system: model.system, initial: [0, 0], step: dt, count: steps)
    for (i, state) in trajectory.enumerated() {
      let shipTime = Double(i + 1) * dt
      #expect(state[1] >= shipTime - 1e-9, "Earth time never falls behind ship time")
    }
    #expect(model.earthTimeTotal > model.shipTimeTotal, "the traveller ages less")
  }

  @Test func massRatioAgreesWithTheRapidityForm() {
    // exp(2·α·τ_flip) equals (1+β)/(1−β) where β is well below 1.
    let model = RelativisticJourneyModel(acceleration: oneG, distance: 4.37)
    let byRapidity = (1 + model.peakBeta) / (1 - model.peakBeta)
    #expect(abs(model.massRatio - byRapidity) / byRapidity < 1e-9)
  }
}
