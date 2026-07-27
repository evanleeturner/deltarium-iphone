import Charts
import SwiftUI

/// Life over the year: benthic biomass and the nutrient pool it feeds on, as two
/// smooth lines. When playing, `now` marks the current day — a sweeping playhead
/// with a dot riding each curve.
struct BenthosLifeChart: View {
  let samples: [BenthosSample]
  let now: BenthosSample?

  var body: some View {
    Chart {
      ForEach(samples) { sample in
        LineMark(
          x: .value("Day", sample.day),
          y: .value("Amount", sample.benthos),
          series: .value("Series", "Life")
        )
        .foregroundStyle(by: .value("Series", "Life"))
        .interpolationMethod(.catmullRom)
        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
      }
      ForEach(samples) { sample in
        LineMark(
          x: .value("Day", sample.day),
          y: .value("Amount", sample.nutrient),
          series: .value("Series", "Nutrient")
        )
        .foregroundStyle(by: .value("Series", "Nutrient"))
        .interpolationMethod(.catmullRom)
        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
      }
      if let now {
        RuleMark(x: .value("Day", now.day))
          .foregroundStyle(.secondary.opacity(0.35))
          .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
        PointMark(x: .value("Day", now.day), y: .value("Amount", now.benthos))
          .foregroundStyle(Palette.benthos)
          .symbolSize(90)
        PointMark(x: .value("Day", now.day), y: .value("Amount", now.nutrient))
          .foregroundStyle(Palette.nutrient)
          .symbolSize(90)
      }
    }
    .chartForegroundStyleScale(["Life": Palette.benthos, "Nutrient": Palette.nutrient])
    .chartXAxis { seasonalAxis() }
    .chartYAxis {
      AxisMarks(values: .automatic(desiredCount: 4)) {
        AxisGridLine().foregroundStyle(.secondary.opacity(0.12))
        AxisValueLabel().font(.caption2).foregroundStyle(.secondary)
      }
    }
    .chartLegend(position: .bottom, spacing: 12)
  }
}

/// The seasons that drive the run: temperature and salinity over the year, so a
/// student can see *why* the population booms and busts.
struct BenthosSeasonsChart: View {
  let samples: [BenthosSample]
  let now: BenthosSample?

  var body: some View {
    Chart {
      ForEach(samples) { sample in
        LineMark(
          x: .value("Day", sample.day),
          y: .value("Value", sample.temperature),
          series: .value("Series", "Temperature")
        )
        .foregroundStyle(by: .value("Series", "Temperature"))
        .interpolationMethod(.catmullRom)
        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
      }
      ForEach(samples) { sample in
        LineMark(
          x: .value("Day", sample.day),
          y: .value("Value", sample.salinity),
          series: .value("Series", "Salinity")
        )
        .foregroundStyle(by: .value("Series", "Salinity"))
        .interpolationMethod(.catmullRom)
        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
      }
      if let now {
        RuleMark(x: .value("Day", now.day))
          .foregroundStyle(.secondary.opacity(0.35))
          .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
      }
    }
    .chartForegroundStyleScale(["Temperature": Palette.predator, "Salinity": Palette.salinity])
    .chartXAxis { seasonalAxis() }
    .chartYAxis {
      AxisMarks(values: .automatic(desiredCount: 4)) {
        AxisGridLine().foregroundStyle(.secondary.opacity(0.12))
        AxisValueLabel().font(.caption2).foregroundStyle(.secondary)
      }
    }
    .chartLegend(position: .bottom, spacing: 12)
  }
}

/// All three calibrated species' biomass on one chart, colour-keyed — for seeing
/// at a glance who thrives under the current settings, and for calibrating the
/// nutrient and starting sliders so each species behaves.
struct BenthosCompareChart: View {
  let traces: [(preset: BenthosPreset, samples: [BenthosSample])]
  let nowDay: Double?

  var body: some View {
    Chart {
      ForEach(traces, id: \.preset.id) { trace in
        ForEach(trace.samples) { sample in
          LineMark(
            x: .value("Day", sample.day),
            y: .value("Life", sample.benthos),
            series: .value("Species", trace.preset.name)
          )
          .foregroundStyle(by: .value("Species", trace.preset.name))
          .interpolationMethod(.catmullRom)
          .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
        }
      }
      if let nowDay {
        RuleMark(x: .value("Day", nowDay))
          .foregroundStyle(.secondary.opacity(0.35))
          .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
      }
    }
    .chartForegroundStyleScale([
      BenthosPreset.streblospio.name: BenthosPreset.streblospio.tint,
      BenthosPreset.laeonereis.name: BenthosPreset.laeonereis.tint,
      BenthosPreset.chironomid.name: BenthosPreset.chironomid.tint,
    ])
    .chartXAxis { seasonalAxis() }
    .chartYAxis {
      AxisMarks(values: .automatic(desiredCount: 4)) {
        AxisGridLine().foregroundStyle(.secondary.opacity(0.12))
        AxisValueLabel().font(.caption2).foregroundStyle(.secondary)
      }
    }
    .chartLegend(position: .bottom, spacing: 12)
  }
}

/// A shared x-axis labelled by season rather than raw day number.
@AxisContentBuilder
private func seasonalAxis() -> some AxisContent {
  AxisMarks(values: [0, 90, 180, 270, 365]) { value in
    AxisGridLine().foregroundStyle(.secondary.opacity(0.12))
    AxisValueLabel {
      if let day = value.as(Double.self) {
        Text(seasonLabel(for: day)).font(.caption2).foregroundStyle(.secondary)
      }
    }
  }
}

private func seasonLabel(for day: Double) -> String {
  switch day {
  case ..<45: "Winter"
  case ..<135: "Spring"
  case ..<225: "Summer"
  case ..<315: "Fall"
  default: "Winter"
  }
}
