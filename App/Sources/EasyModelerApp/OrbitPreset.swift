import EasyModelerKit

/// A one-tap starting arrangement for the three-body stage, named by what you'll
/// see. The figure-8 is the stable front door — three equal stars on one looping
/// 8 — and the others are the chaos it tips into: the Pythagorean fall-and-fling,
/// and a tangle that leaves the plane. Each wraps a Kit `ThreeBodyConfiguration`
/// (the shared physics) with its presentation.
struct OrbitPreset: Identifiable {
  let name: String
  let symbol: String
  let configuration: ThreeBodyConfiguration

  var id: String { name }

  static let gallery: [OrbitPreset] = [
    OrbitPreset(
      name: "Figure 8", symbol: "infinity", configuration: .figureEight),
    OrbitPreset(
      name: "Pythagoras", symbol: "triangle", configuration: .pythagorean),
    OrbitPreset(
      name: "3D tangle", symbol: "tornado", configuration: .tangle),
  ]

  /// The default landing arrangement — the stable, mesmerizing figure-8.
  static var figureEight: OrbitPreset { gallery[0] }
}
