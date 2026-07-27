/// One sampled instant of a decay run: the time (years) and the radioactivity
/// level (relative percent — total activity across the source's chains, normalized
/// and scaled by concentration and distance). `Identifiable` by time so Swift Charts
/// can key the marks.
struct RadioactivitySample: Identifiable {
  let t: Double
  let level: Double

  var id: Double { t }
}
