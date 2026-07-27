import Charts
import SwiftUI

/// The phase portrait: predators against prey, tracing the closed loop the pair
/// cycles around. The green dot marks the start; when playing, a bright "now"
/// dot travels the loop so you can watch time run. When idle, an orange dot
/// marks where the run ends.
struct PhasePortraitChart: View {
  let samples: [PopulationSample]
  let now: PopulationSample?

  var body: some View {
    Chart {
      ForEach(samples) { sample in
        LineMark(
          x: .value("Prey", sample.prey),
          y: .value("Predators", sample.predator)
        )
        .interpolationMethod(.catmullRom)
        .foregroundStyle(Palette.brand)
        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
      }
      if let start = samples.first {
        PointMark(x: .value("Prey", start.prey), y: .value("Predators", start.predator))
          .foregroundStyle(Palette.prey)
          .symbolSize(120)
      }
      if let now {
        PointMark(x: .value("Prey", now.prey), y: .value("Predators", now.predator))
          .foregroundStyle(.white)
          .symbolSize(200)
      } else if let end = samples.last {
        PointMark(x: .value("Prey", end.prey), y: .value("Predators", end.predator))
          .foregroundStyle(Palette.predator)
          .symbolSize(120)
      }
    }
    .chartXAxis {
      AxisMarks(values: .automatic(desiredCount: 4)) {
        AxisGridLine().foregroundStyle(.secondary.opacity(0.12))
        AxisValueLabel().font(.caption2).foregroundStyle(.secondary)
      }
    }
    .chartYAxis {
      AxisMarks(values: .automatic(desiredCount: 4)) {
        AxisGridLine().foregroundStyle(.secondary.opacity(0.12))
        AxisValueLabel().font(.caption2).foregroundStyle(.secondary)
      }
    }
    .chartXAxisLabel("Prey")
    .chartYAxisLabel("Predators")
  }
}
