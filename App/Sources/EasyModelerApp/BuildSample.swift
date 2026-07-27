/// One sampled instant of a user-built run: the time and every state variable's
/// value at that time, in the same order as the system's state names.
/// `Identifiable` by time so Swift Charts can key the marks.
struct BuildSample: Identifiable {
  let t: Double
  let values: [Double]

  var id: Double { t }
}
