import SwiftUI
import UIKit

/// The estuary playground: an open benthos–nutrient system that never settles.
/// Feed it and set the starting populations; the seasons run underneath and push
/// it through a bloom and a summer crash. A segmented switch shows either the
/// life (biomass and its food) or the seasons driving it, a species row swaps in
/// the real calibrated creatures, and the shared transport plays the year.
///
/// Motion rules match the other screens: a slider drag re-integrates instantly
/// (no `withAnimation`); discrete jumps (a species, Reset, a mode switch) spring
/// and tick, nil under Reduce Motion.
struct BenthosScreen: View {
  @State private var model = BenthosModel()
  @State private var chartMode: ChartMode = .life
  @State private var resetSpin = 0.0
  @State private var playback = PlaybackModel(horizon: 365, sweepDuration: 10)
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  enum ChartMode: String, CaseIterable, Identifiable {
    case life = "Life"
    case seasons = "Seasons"
    case compare = "All three"

    var id: Self { self }

    var caption: String {
      switch self {
      case .life: "Benthic life and the nutrient it feeds on, over a year."
      case .seasons: "The temperature and salinity driving the bloom and the crash."
      case .compare: "All three species at once — who thrives under these settings."
      }
    }
  }

  private var chartAnimation: Animation? {
    reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.85)
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        Text(
          "Feed the estuary and pick who lives there — watch life bloom, "
            + "then crash in summer."
        )
        .font(.subheadline)
        .foregroundStyle(.secondary)
        speciesRow
        chartCard
        controls
        ScienceCard(note: .benthos)
      }
      .padding()
    }
    .background {
      ZStack(alignment: .top) {
        Color(uiColor: .systemGroupedBackground)
        LinearGradient(
          colors: [Palette.benthos.opacity(0.12), .clear],
          startPoint: .top, endPoint: .bottom
        )
        .frame(height: 340)
        .frame(maxWidth: .infinity, alignment: .top)
      }
      .ignoresSafeArea()
    }
    .navigationTitle("Estuary")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button {
          withAnimation(chartAnimation) {
            model.reset()
            resetSpin -= 360
          }
        } label: {
          Image(systemName: "arrow.counterclockwise")
            .rotationEffect(.degrees(resetSpin))
        }
        .accessibilityLabel("Start over")
      }
    }
    .fontDesign(.rounded)
    .tint(Palette.benthos)
    .onAppear { playback.horizon = model.horizon }
    .sensoryFeedback(.selection, trigger: chartMode)
    .sensoryFeedback(.selection, trigger: playback.isPlaying)
    .sensoryFeedback(.selection, trigger: playback.speedIndex)
    .sensoryFeedback(.impact(flexibility: .soft), trigger: model.discreteEventCount)
  }

  private var speciesRow: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 10) {
        ForEach(BenthosPreset.gallery) { preset in
          Button {
            withAnimation(chartAnimation) {
              model.apply(preset)
            }
          } label: {
            Label(preset.name, systemImage: preset.symbol)
              .font(.subheadline)
              .padding(.horizontal, 14)
              .padding(.vertical, 8)
              .background(
                model.species == preset
                  ? AnyShapeStyle(Palette.benthos.opacity(0.2))
                  : AnyShapeStyle(.thinMaterial), in: Capsule())
          }
          .buttonStyle(.plain)
        }
      }
      .padding(.horizontal, 2)
    }
  }

  private var chartCard: some View {
    VStack(spacing: 12) {
      Picker("View", selection: $chartMode) {
        ForEach(ChartMode.allCases) { mode in
          Text(mode.rawValue).tag(mode)
        }
      }
      .pickerStyle(.segmented)

      Text(chartMode.caption)
        .font(.footnote)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)

      chartArea
      TransportBar(playback: playback, tint: Palette.benthos)

      if !model.insight.isEmpty {
        Label(model.insight, systemImage: "sparkles")
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
    .padding()
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
    .shadow(color: .black.opacity(0.08), radius: 12, y: 6)
  }

  private var chartArea: some View {
    Group {
      if playback.isPlaying {
        TimelineView(.animation) { context in
          charts(now: model.sample(at: playback.playhead(at: context.date)))
        }
      } else {
        charts(now: playback.restingHead.map { model.sample(at: $0) })
      }
    }
    .frame(height: 280)
    .id(chartMode)
    .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.98)))
    .animation(reduceMotion ? nil : .snappy, value: chartMode)
  }

  @ViewBuilder
  private func charts(now: BenthosSample?) -> some View {
    switch chartMode {
    case .life:
      BenthosLifeChart(samples: model.samples, now: now)
    case .seasons:
      BenthosSeasonsChart(samples: model.samples, now: now)
    case .compare:
      BenthosCompareChart(traces: model.allTraces, nowDay: now?.day)
    }
  }

  private var controls: some View {
    VStack(alignment: .leading, spacing: 20) {
      controlSection("Feeding the estuary", systemImage: "drop.fill") {
        ParameterSlider(
          title: "Nutrient input", symbol: "drop.fill", tint: Palette.nutrient,
          range: 0...100, value: bind(\.nutrientInput))
        Text("Flows in every day. Hungry species (ragworm, midge) need a lot.")
          .font(.footnote)
          .foregroundStyle(.secondary)
      }
      controlSection("Water conditions", systemImage: "water.waves") {
        ParameterSlider(
          title: "Salinity", symbol: "water.waves", tint: Palette.salinity,
          range: 2...30, value: bind(\.salinityMean))
        ParameterSlider(
          title: "Temperature", symbol: "thermometer.medium", tint: Palette.predator,
          range: 8...32, value: bind(\.temperatureMean))
        Text("Wetter or drier, cooler or warmer — nudge toward a species' sweet spot.")
          .font(.footnote)
          .foregroundStyle(.secondary)
      }
      controlSection("Starting out", systemImage: "leaf.fill") {
        ParameterSlider(
          title: "Starting life", symbol: "ant.fill", tint: Palette.benthos,
          range: 0...12, value: bind(\.startingLife))
        ParameterSlider(
          title: "Starting nutrients", symbol: "drop.fill", tint: Palette.nutrient,
          range: 0...30, value: bind(\.startingNutrient))
      }
    }
  }

  private func controlSection(
    _ title: String, systemImage: String, @ViewBuilder _ content: () -> some View
  ) -> some View {
    VStack(alignment: .leading, spacing: 14) {
      Label(title, systemImage: systemImage)
        .font(.headline)
      content()
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding()
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
  }

  /// A binding that writes the parameter and re-integrates on every change with
  /// NO animation, so the chart tracks the slider live.
  private func bind(_ keyPath: ReferenceWritableKeyPath<BenthosModel, Double>)
    -> Binding<Double>
  {
    Binding(
      get: { model[keyPath: keyPath] },
      set: {
        model[keyPath: keyPath] = $0
        model.recompute()
      })
  }
}
