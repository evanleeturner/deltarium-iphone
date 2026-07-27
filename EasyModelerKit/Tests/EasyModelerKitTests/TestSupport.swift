/// Shared numeric helpers for the fence suite. The Swift Testing binding wants
/// a tolerance for any floating magnitude that isn't a provably-terminating
/// exact; these keep the comparisons uniform across suites.

/// Absolute closeness for a single magnitude.
func isClose(_ a: Double, _ b: Double, tolerance: Double = 1e-12) -> Bool {
  abs(a - b) <= tolerance
}

/// The largest absolute component difference between two equally-shaped
/// trajectories (the fidelity distance to the reference).
func maxAbsDifference(_ a: [[Double]], _ b: [[Double]]) -> Double {
  var worst = 0.0
  for (rowA, rowB) in zip(a, b) {
    for (x, y) in zip(rowA, rowB) {
      worst = max(worst, abs(x - y))
    }
  }
  return worst
}

/// Per-component `(min, max)` over a trajectory — the observed extent of each
/// state variable, used to build oracle-derived bounding boxes (no invented
/// magnitudes).
func componentBounds(_ rows: [[Double]]) -> [(min: Double, max: Double)] {
  guard let first = rows.first else { return [] }
  var bounds = first.map { (min: $0, max: $0) }
  for row in rows {
    for i in row.indices {
      bounds[i].min = min(bounds[i].min, row[i])
      bounds[i].max = max(bounds[i].max, row[i])
    }
  }
  return bounds
}
