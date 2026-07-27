import EasyModelerKit
import SwiftUI
import UIKit

/// The radioactivity playground — "Radioactivity". A radiation trefoil and the
/// question head the screen; a source picker chooses what was released; the chart is
/// the hero, showing the activity falling toward a safe background as time runs; and
/// the sliders below set how much and how far away.
///
/// This is a 2D chart screen (like predator–prey), pushed by `HomeScreen`. Motion
/// rules match the others: a slider drag re-integrates instantly, while the source
/// switch and Reset spring and tick, nil under Reduce Motion.
struct RadioactivityScreen: View {
  @State private var model = RadioactivityModel()
  @State private var playback = PlaybackModel(horizon: 300, sweepDuration: 12)
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  private var springAnimation: Animation? {
    reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.85)
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        header
        sourceCard
        chartCard
        if model.usesDoseControls { doseCard }
        ScienceCard(note: .radioactivity)
      }
      .padding()
    }
    .background { backgroundWash }
    .navigationTitle("Radioactivity")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button {
          withAnimation(springAnimation) { model.reset() }
        } label: {
          Image(systemName: "arrow.counterclockwise")
        }
        .accessibilityLabel("Start over")
      }
    }
    .fontDesign(.rounded)
    .tint(Palette.brand)
    .onAppear { playback.horizon = model.horizon }
    .sensoryFeedback(.selection, trigger: playback.isPlaying)
    .sensoryFeedback(.selection, trigger: playback.speedIndex)
    .sensoryFeedback(.impact(flexibility: .soft), trigger: model.discreteEventCount)
  }

  // MARK: - Header

  private var header: some View {
    HStack(spacing: 16) {
      RadiationSymbol()
        .frame(width: 52, height: 52)
      VStack(alignment: .leading, spacing: 4) {
        Text("Radioactivity")
          .font(.title2.bold())
        Text("How long does it take for radioactivity to dissipate in the environment naturally?")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }
    }
  }

  // MARK: - Source

  private var sourceCard: some View {
    VStack(alignment: .leading, spacing: 10) {
      Picker("Source", selection: sourceBinding) {
        ForEach(Array(RadiationSource.all.enumerated()), id: \.offset) { index, source in
          Text(source.name).tag(index)
        }
      }
      .pickerStyle(.segmented)

      Text(model.sourceDescription)
        .font(.footnote)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding()
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
  }

  // MARK: - Chart

  private var chartCard: some View {
    VStack(spacing: 12) {
      chartArea
      TransportBar(playback: playback, tint: Palette.radiation)

      Label(model.insight, systemImage: "clock.arrow.circlepath")
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.leading)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding()
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
    .shadow(color: .black.opacity(0.08), radius: 12, y: 6)
  }

  private var chartArea: some View {
    Group {
      if playback.isPlaying {
        TimelineView(.animation) { context in
          RadioactivityChart(
            samples: model.samples, now: model.sample(at: playback.playhead(at: context.date)),
            safeLevel: model.isNaturalBackground ? nil : model.safeLevel,
            halfLife: model.datingHalfLife)
        }
      } else {
        RadioactivityChart(
          samples: model.samples, now: playback.restingHead.map { model.sample(at: $0) },
          safeLevel: model.isNaturalBackground ? nil : model.safeLevel,
          halfLife: model.datingHalfLife)
      }
    }
    .frame(height: 260)
  }

  // MARK: - Dose controls

  private var doseCard: some View {
    VStack(alignment: .leading, spacing: 14) {
      Label("Where and how much", systemImage: "slider.horizontal.3")
        .font(.headline)
      ParameterSlider(
        title: "Distance", symbol: "figure.walk", tint: Palette.safe,
        range: 0...100, value: bind(\.distanceMiles))
      ParameterSlider(
        title: "Concentration", symbol: "smoke.fill", tint: Palette.radiation,
        range: 0.2...3, value: bind(\.concentration))
      Text("Distance dims what reaches you; a bigger release raises the level everywhere.")
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding()
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
  }

  private var backgroundWash: some View {
    ZStack(alignment: .top) {
      Color(uiColor: .systemGroupedBackground)
      LinearGradient(
        colors: [Palette.radiation.opacity(0.12), .clear],
        startPoint: .top, endPoint: .bottom
      )
      .frame(height: 340)
      .frame(maxWidth: .infinity, alignment: .top)
    }
    .ignoresSafeArea()
  }

  // MARK: - Bindings

  private var sourceBinding: Binding<Int> {
    Binding(
      get: { model.sourceIndex },
      set: { index in
        withAnimation(springAnimation) {
          model.selectSource(index)
          playback.horizon = model.horizon
        }
      })
  }

  /// A binding that writes the parameter and re-integrates on every change with NO
  /// animation, so the chart tracks the slider live.
  private func bind(_ keyPath: ReferenceWritableKeyPath<RadioactivityModel, Double>)
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
