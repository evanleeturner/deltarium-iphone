import Charts
import SwiftUI

/// Radioactivity over time: one line falling from its peak toward zero, with a green
/// "safe background" line to read the crossing against. When playing, `now` marks the
/// current instant — a sweeping playhead with a dot riding the curve.
struct RadioactivityChart: View {
  let samples: [RadioactivitySample]
  let now: RadioactivitySample?
  /// The "safe background" level to draw, for contamination sources; nil hides it
  /// (Carbon-14 is itself natural background, so it has no safe line).
  let safeLevel: Double?
  /// A half-life to mark as a dating clock (Carbon-14); nil hides it.
  let halfLife: Double?

  var body: some View {
    Chart {
      ForEach(samples) { sample in
        LineMark(
          x: .value("Time", sample.t),
          y: .value("Radioactivity", sample.level)
        )
        .foregroundStyle(Palette.radiation)
        .interpolationMethod(.catmullRom)
        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
      }

      if let safeLevel {
        RuleMark(y: .value("Safe", safeLevel))
          .foregroundStyle(Palette.safe)
          .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
          .annotation(position: .top, alignment: .leading) {
            Text("safe background")
              .font(.caption2)
              .foregroundStyle(Palette.safe)
          }
      }

      if let halfLife {
        RuleMark(x: .value("Half-life", halfLife))
          .foregroundStyle(Palette.safe)
          .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
          .annotation(position: .top, alignment: .center) {
            Text("one half-life")
              .font(.caption2)
              .foregroundStyle(Palette.safe)
          }
        PointMark(x: .value("Half-life", halfLife), y: .value("Radioactivity", 50))
          .foregroundStyle(Palette.safe)
          .symbolSize(70)
      }

      if let now {
        RuleMark(x: .value("Time", now.t))
          .foregroundStyle(.secondary.opacity(0.35))
          .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
        PointMark(x: .value("Time", now.t), y: .value("Radioactivity", now.level))
          .foregroundStyle(Palette.radiation)
          .symbolSize(90)
      }
    }
    .chartXAxis {
      AxisMarks(values: .automatic(desiredCount: 5)) { value in
        AxisGridLine().foregroundStyle(.secondary.opacity(0.12))
        AxisValueLabel {
          if let years = value.as(Double.self) {
            Text(Self.yearsLabel(years))
          }
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
      }
    }
    .chartYAxis {
      AxisMarks(values: .automatic(desiredCount: 4)) { value in
        AxisGridLine().foregroundStyle(.secondary.opacity(0.12))
        AxisValueLabel {
          if let level = value.as(Double.self) {
            Text("\(Int(level))%")
          }
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
      }
    }
    .chartYScale(domain: 0...110)
    .chartPlotStyle { plot in
      plot.padding(.top, 8)
    }
  }

  /// Compact year labels: "300 yr", "5k yr", "250k yr".
  private static func yearsLabel(_ years: Double) -> String {
    if years < 1000 { return "\(Int(years.rounded())) yr" }
    return "\(Int((years / 1000).rounded()))k yr"
  }
}
