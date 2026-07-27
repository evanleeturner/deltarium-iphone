import SwiftUI
import UIKit

/// The predator–prey playground. Presets hand a first-timer an instant "try
/// this"; the elevated chart is the hero, with two views of the same run behind
/// a segmented switch, a **Play** transport that runs time through both views,
/// and a one-line plain-language read of what it's doing; the sliders below
/// recede into quieter cards and re-integrate live.
///
/// This is a plain view pushed by `HomeScreen`'s `NavigationStack`. Motion
/// rules: a slider *drag* is instant — the binding writes without
/// `withAnimation`, so the chart tracks the finger. Discrete jumps (a preset,
/// Reset, a mode switch) spring and tick, nil under Reduce Motion via
/// `chartAnimation`. Playback is a wall-clock `TimelineView` sweep (see
/// `PlaybackModel`) that keeps running over whatever trajectory the sliders make.
struct PredatorPreyScreen: View {
  @State private var model = PredatorPreyModel()
  @State private var chartMode: ChartMode = .overTime
  @State private var resetSpin = 0.0
  @State private var playback = PlaybackModel(horizon: 20, sweepDuration: 8)
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  enum ChartMode: String, CaseIterable, Identifiable {
    case overTime = "Over time"
    case theLoop = "The loop"

    var id: Self { self }

    var caption: String {
      switch self {
      case .overTime: "Watch the two populations chase over time."
      case .theLoop: "The same run drawn as a loop — see how it circles back."
      }
    }
  }

  private var chartAnimation: Animation? {
    reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.85)
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        Text("Move the sliders — watch the populations rise, crash, and chase each other.")
          .font(.subheadline)
          .foregroundStyle(.secondary)
        presetRow
        chartCard
        controls
        ScienceCard(note: .lotkaVolterra)
      }
      .padding()
    }
    .background {
      ZStack(alignment: .top) {
        Color(uiColor: .systemGroupedBackground)
        LinearGradient(
          colors: [Palette.brand.opacity(0.12), .clear],
          startPoint: .top, endPoint: .bottom
        )
        .frame(height: 340)
        .frame(maxWidth: .infinity, alignment: .top)
      }
      .ignoresSafeArea()
    }
    .navigationTitle("Predator & Prey")
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
    .tint(Palette.brand)
    .onAppear { playback.horizon = model.horizon }
    .sensoryFeedback(.selection, trigger: chartMode)
    .sensoryFeedback(.selection, trigger: playback.isPlaying)
    .sensoryFeedback(.selection, trigger: playback.speedIndex)
    .sensoryFeedback(.impact(flexibility: .soft), trigger: model.discreteEventCount)
  }

  private var presetRow: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 10) {
        ForEach(Preset.gallery) { preset in
          Button {
            withAnimation(chartAnimation) {
              model.apply(preset)
            }
          } label: {
            Label(preset.name, systemImage: preset.symbol)
              .font(.subheadline)
              .padding(.horizontal, 14)
              .padding(.vertical, 8)
              .background(.thinMaterial, in: Capsule())
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
      TransportBar(playback: playback)

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

  /// The chart, driven by a wall-clock playhead while playing, static otherwise.
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
  private func charts(now: PopulationSample?) -> some View {
    switch chartMode {
    case .overTime:
      PopulationChart(samples: model.samples, now: now)
    case .theLoop:
      PhasePortraitChart(samples: model.samples, now: now)
    }
  }

  private var controls: some View {
    VStack(alignment: .leading, spacing: 20) {
      controlSection("Starting populations", systemImage: "leaf.fill") {
        ParameterSlider(
          title: "Starting prey", symbol: "hare.fill", tint: Palette.prey,
          range: 0.5...5, value: bind(\.startingPrey))
        ParameterSlider(
          title: "Starting predators", symbol: "pawprint.fill", tint: Palette.predator,
          range: 0.5...5, value: bind(\.startingPredators))
      }
      controlSection("Interaction rates", systemImage: "slider.horizontal.3") {
        ParameterSlider(
          title: "Prey multiply", symbol: "arrow.up.forward", tint: Palette.prey,
          range: 0.2...2, value: bind(\.preyGrowth))
        ParameterSlider(
          title: "Hunting", symbol: "bolt.fill", tint: Palette.predator,
          range: 0.2...2, value: bind(\.predation))
        ParameterSlider(
          title: "Predators die off", symbol: "arrow.down.forward", tint: Palette.predator,
          range: 0.2...2, value: bind(\.predatorDeath))
        ParameterSlider(
          title: "Predators thrive", symbol: "arrow.up.right.circle", tint: Palette.predator,
          range: 0.2...2, value: bind(\.predatorGrowth))
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
  /// NO animation, so the chart tracks the slider live (springs are reserved for
  /// discrete jumps).
  private func bind(_ keyPath: ReferenceWritableKeyPath<PredatorPreyModel, Double>)
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
