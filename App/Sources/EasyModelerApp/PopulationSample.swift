/// One sampled instant of a predator–prey run: the time and the two
/// populations. `Identifiable` by time so Swift Charts can key the marks.
struct PopulationSample: Identifiable {
  let t: Double
  let prey: Double
  let predator: Double

  var id: Double { t }
}
