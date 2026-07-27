import Charts
import SwiftUI

/// Populations over time: prey and predators as two smooth, weighted lines that
/// rise, crash, and chase each other. When playing, `now` marks the current
/// instant — a sweeping playhead line with a dot riding each curve.
struct PopulationChart: View {
  let samples: [PopulationSample]
  let now: PopulationSample?

  var body: some View {
    Chart {
      ForEach(samples) { sample in
        LineMark(
          x: .value("Time", sample.t),
          y: .value("Population", sample.prey),
          series: .value("Species", "Prey")
        )
        .foregroundStyle(by: .value("Species", "Prey"))
        .interpolationMethod(.catmullRom)
        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
      }
      ForEach(samples) { sample in
        LineMark(
          x: .value("Time", sample.t),
          y: .value("Population", sample.predator),
          series: .value("Species", "Predators")
        )
        .foregroundStyle(by: .value("Species", "Predators"))
        .interpolationMethod(.catmullRom)
        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
      }
      if let now {
        RuleMark(x: .value("Time", now.t))
          .foregroundStyle(.secondary.opacity(0.35))
          .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
        PointMark(x: .value("Time", now.t), y: .value("Population", now.prey))
          .foregroundStyle(Palette.prey)
          .symbolSize(90)
        PointMark(x: .value("Time", now.t), y: .value("Population", now.predator))
          .foregroundStyle(Palette.predator)
          .symbolSize(90)
      }
    }
    .chartForegroundStyleScale(["Prey": Palette.prey, "Predators": Palette.predator])
    .chartXAxis {
      AxisMarks(values: .automatic(desiredCount: 5)) {
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
    .chartLegend(position: .bottom, spacing: 12)
    .chartPlotStyle { plot in
      plot.padding(.top, 8)
    }
  }
}
