/// One instant of the relativistic journey, parametrized by the ship's own
/// clock: how much ship time and Earth time have passed, how far the ship has
/// travelled, and how fast it is going. `Identifiable` by ship time for the
/// chart and the worldtube rings.
struct RelativitySample: Identifiable {
  /// The ship's proper time so far (years) — the parameter the journey runs on.
  let shipYears: Double
  /// Earth (coordinate) time so far (years) — races ahead of ship time.
  let earthYears: Double
  /// Distance covered (light-years).
  let distanceLightYears: Double
  /// Speed as a fraction of c.
  let beta: Double

  var id: Double { shipYears }
}
