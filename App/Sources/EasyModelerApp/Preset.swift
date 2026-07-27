/// A one-tap starting point: all six parameters at once, named by the behaviour
/// you'll see rather than by a claim about who wins (pure Lotka-Volterra can't
/// truly drive a species extinct, so the names stay honest). Presets turn the
/// blank-canvas paralysis of six sliders into "tap and watch it change."
///
/// The numbers are sensible defaults tuned against the fixed 20-unit horizon;
/// they are worth refining on-device once the owner sees how many cycles each
/// packs into the window.
struct Preset: Identifiable {
  let name: String
  let symbol: String
  let preyGrowth: Double
  let predation: Double
  let predatorDeath: Double
  let predatorGrowth: Double
  let startingPrey: Double
  let startingPredators: Double

  var id: String { name }

  static let gallery: [Preset] = [
    Preset(
      name: "Balanced cycle", symbol: "arrow.triangle.2.circlepath",
      preyGrowth: 1, predation: 1, predatorDeath: 1, predatorGrowth: 1,
      startingPrey: 3, startingPredators: 2),
    Preset(
      name: "Wild swings", symbol: "waveform",
      preyGrowth: 1.5, predation: 1.4, predatorDeath: 0.8, predatorGrowth: 1.4,
      startingPrey: 4, startingPredators: 1),
    Preset(
      name: "Fast & furious", symbol: "hare.fill",
      preyGrowth: 1.8, predation: 1.8, predatorDeath: 1.8, predatorGrowth: 1.8,
      startingPrey: 3, startingPredators: 2),
    Preset(
      name: "Slow & steady", symbol: "tortoise.fill",
      preyGrowth: 0.5, predation: 0.5, predatorDeath: 0.5, predatorGrowth: 0.5,
      startingPrey: 3, startingPredators: 2),
    Preset(
      name: "Prey heavy", symbol: "leaf.fill",
      preyGrowth: 1, predation: 1, predatorDeath: 1, predatorGrowth: 1,
      startingPrey: 5, startingPredators: 1),
  ]
}
