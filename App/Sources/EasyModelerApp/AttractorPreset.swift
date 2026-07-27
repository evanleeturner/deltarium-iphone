/// A one-tap Lorenz regime, named by what you'll see. Sweeping `rho` walks the
/// system from a calm settling point, through the edge of chaos, into the
/// textbook butterfly, and on to the deep-chaos regime the tier-2 reference
/// runs. `sigma` and `beta` stay at their classic values except in "Wild chaos"
/// (`beta = 2`), matching the Python example.
///
/// The numbers are sensible teaching defaults against the fixed horizon; worth
/// refining on-device once the owner sees how each fills the 3D stage.
struct AttractorPreset: Identifiable {
  let name: String
  let symbol: String
  let sigma: Double
  let rho: Double
  let beta: Double

  var id: String { name }

  static let gallery: [AttractorPreset] = [
    AttractorPreset(
      name: "Calm", symbol: "circle.dotted", sigma: 10, rho: 14, beta: 8.0 / 3.0),
    AttractorPreset(
      name: "On the edge", symbol: "scribble.variable", sigma: 10, rho: 24, beta: 8.0 / 3.0),
    AttractorPreset(
      name: "Classic butterfly", symbol: "tornado", sigma: 10, rho: 28, beta: 8.0 / 3.0),
    AttractorPreset(
      name: "Wild chaos", symbol: "hurricane", sigma: 10, rho: 99.96, beta: 2),
  ]

  /// The default landing regime — the textbook attractor that the app icon draws.
  static var classicButterfly: AttractorPreset { gallery[2] }
}
