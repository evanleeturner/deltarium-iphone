/// One sampled instant of a Lorenz run: the time and the 3D state `(x, y, z)`.
/// `Identifiable` by time so views can key it.
struct AttractorSample: Identifiable {
  let t: Double
  let x: Double
  let y: Double
  let z: Double

  var id: Double { t }
}
