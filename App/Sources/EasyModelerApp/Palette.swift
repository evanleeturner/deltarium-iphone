import SwiftUI

/// The app's colour language, in one place. Prey reads green, predators orange —
/// the same hues carry the chart lines, the sliders that move them, and the
/// legend, so the colour *is* the label. Brand is the accent for controls and
/// selection. System colours are used deliberately: they adapt to light and
/// dark on their own, and the richness comes from weight and gradient, not from
/// hand-picked RGB that would need re-tuning per mode.
enum Palette {
  static let prey = Color.green
  static let predator = Color.orange
  static let brand = Color.indigo
  /// The Lorenz attractor's line — a luminous cyan on the dark 3D stage; also
  /// the accent for the butterfly screen.
  static let attractor = Color.cyan
  /// The butterfly-effect twin path, drawn warm so its divergence reads clearly
  /// against the cyan original.
  static let twin = Color.pink
  /// Benthic life (biomass) in the estuary playground.
  static let benthos = Color.teal
  /// The nutrient / food pool in the water column.
  static let nutrient = Color.brown
  /// Salinity, in the seasonal-conditions view (temperature reuses `predator`).
  static let salinity = Color.blue
  /// The three stars on the gravity stage. The stage is always dark (like the
  /// attractor's), so these are picked to be vivid and mutually distinct on black
  /// rather than to adapt to light mode. Body 0 (the one the "heavier" knob grows)
  /// leads in warm amber.
  static let starA = Color.orange
  static let starB = Color.cyan
  static let starC = Color.purple
  /// Earth and the Moon on the Lagrange stage (always dark), and the five
  /// satellites keyed to L1…L5 — distinct hues, chosen not to encode the answer
  /// (which points are stable) so the student discovers it by watching.
  static let earth = Color.blue
  static let moon = Color(white: 0.7)
  static let satellites: [Color] = [.yellow, .orange, .pink, .green, .cyan]
  /// The radioactivity playground: the trefoil and the decay curve read in a warning
  /// amber, and the "safe background" line and distance in a reassuring green.
  static let radiation = Color.yellow
  static let safe = Color.green
  /// The build-your-own playground's accent — a fresh mint for the controls and
  /// the header, distinct from the other models' hues.
  static let builder = Color.mint
  /// The guided tour's accent — a warm pink for the learning path, distinct from
  /// the other home cards.
  static let guide = Color.pink
  /// The relativistic-journey accent (destination marker, spacecraft, controls).
  static let relativity = Color.cyan
  /// The spacetime worldtube and its proper-time rings, orange like the reference.
  static let worldline = Color.orange
  /// The Sun at the journey's origin.
  static let sol = Color.yellow
  /// The line palette for a built system's state variables — up to six mutually
  /// distinct hues, keyed to the legend so the colour is the label.
  static let series: [Color] = [.teal, .orange, .purple, .pink, .green, .blue]

  /// The colour for state variable `index`, wrapping if a system somehow exceeds
  /// the palette.
  static func seriesColor(_ index: Int) -> Color {
    series[index % series.count]
  }
}
