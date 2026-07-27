import EasyModelerKit
import SwiftUI

/// One of the three Rincon Bayou marsh species the Benthic Ecology Model was
/// calibrated to (2016 paper, Table 4). Each carries its own fitted growth,
/// mortality, and salinity/temperature optima, so the same seasonal year favours
/// each at a different time — the fresh-loving midge peaks apart from the more
/// brackish worm. The high-mortality species need a far larger sustained nutrient
/// input to hold on, which is what the nutrient slider is for. The open-system
/// knobs (burial, recycle, recruitment) stay shared.
struct BenthosPreset: Identifiable, Equatable {
  let name: String
  let symbol: String
  let tint: Color
  let growthScale: Double
  let salinityWidth: Double
  let temperatureWidth: Double
  let mortality: Double
  let optimalSalinity: Double
  let optimalTemperature: Double

  var id: String { name }

  /// The Kit model with this species' coefficients; the caller sets `foodInput`
  /// from the slider before integrating.
  var model: OpenBenthosModel {
    OpenBenthosModel(
      growthScale: growthScale, carryingCapacity: 12, salinityWidth: salinityWidth,
      temperatureWidth: temperatureWidth, mortality: mortality,
      optimalSalinity: optimalSalinity, optimalTemperature: optimalTemperature)
  }

  static func == (lhs: BenthosPreset, rhs: BenthosPreset) -> Bool { lhs.id == rhs.id }

  static let streblospio = BenthosPreset(
    name: "Bristle worm", symbol: "tornado", tint: Palette.benthos, growthScale: 8.78,
    salinityWidth: 2.94, temperatureWidth: 5.48, mortality: 0.23, optimalSalinity: 13.47,
    optimalTemperature: 16.47)
  static let laeonereis = BenthosPreset(
    name: "Ragworm", symbol: "scribble.variable", tint: Palette.predator, growthScale: 15.77,
    salinityWidth: 11.04, temperatureWidth: 5.49, mortality: 6.13, optimalSalinity: 6.78,
    optimalTemperature: 16.59)
  static let chironomid = BenthosPreset(
    name: "Midge larva", symbol: "ant.fill", tint: .purple, growthScale: 47,
    salinityWidth: 11.9, temperatureWidth: 2.5, mortality: 7.3, optimalSalinity: 4.6,
    optimalTemperature: 12.8)

  static let gallery: [BenthosPreset] = [streblospio, laeonereis, chironomid]
}
