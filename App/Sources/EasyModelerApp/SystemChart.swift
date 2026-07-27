import Charts
import SwiftUI

/// The user-built system over time: one coloured line per state variable, a
/// legend keyed to those colours, and a sweeping playhead with a dot riding each
/// curve. A general 2D time-series plot, since a built system can have any shape
/// (the y-axis auto-scales to whatever the equations produce).
struct SystemChart: View {
  let samples: [BuildSample]
  let seriesNames: [String]
  let now: BuildSample?

  private var colors: [Color] { seriesNames.indices.map { Palette.seriesColor($0) } }

  var body: some View {
    Chart {
      ForEach(Array(seriesNames.enumerated()), id: \.offset) { index, name in
        ForEach(samples) { sample in
          if index < sample.values.count, sample.values[index].isFinite {
            LineMark(
              x: .value("Time", sample.t),
              y: .value("Value", sample.values[index]),
              series: .value("Series", name)
            )
            .foregroundStyle(by: .value("Series", name))
            .interpolationMethod(.catmullRom)
            .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
          }
        }
      }

      if let now {
        RuleMark(x: .value("Time", now.t))
          .foregroundStyle(.secondary.opacity(0.35))
          .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
        ForEach(Array(seriesNames.enumerated()), id: \.offset) { index, name in
          if index < now.values.count, now.values[index].isFinite {
            PointMark(
              x: .value("Time", now.t),
              y: .value("Value", now.values[index])
            )
            .foregroundStyle(by: .value("Series", name))
            .symbolSize(80)
          }
        }
      }
    }
    .chartForegroundStyleScale(domain: seriesNames, range: colors)
    .chartXAxis {
      AxisMarks(values: .automatic(desiredCount: 5)) { _ in
        AxisGridLine().foregroundStyle(.secondary.opacity(0.12))
        AxisTick()
        AxisValueLabel()
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
    }
    .chartYAxis {
      AxisMarks(values: .automatic(desiredCount: 4)) { _ in
        AxisGridLine().foregroundStyle(.secondary.opacity(0.12))
        AxisTick()
        AxisValueLabel()
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
    }
    .chartLegend(position: .bottom, spacing: 8)
    .chartPlotStyle { plot in
      plot.padding(.top, 8)
    }
  }
}
