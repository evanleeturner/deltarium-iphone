import SwiftUI
import UIKit

/// The Lorenz playground. Unlike the predator–prey screen, the hero is a live 3D
/// stage you orbit and pinch, so it is **pinned** above a scrolling control
/// panel rather than living inside the scroll — that keeps the attractor's
/// orbit gesture from fighting the scroll view for vertical drags.
///
/// The headline knob is "Chaos" (`rho`), which walks the system from a calm
/// settling point into the endless butterfly; the twin toggle is the
/// butterfly-effect lesson. Motion rules match the other screen: a slider drag
/// re-integrates instantly (no `withAnimation`), while presets, Reset, and the
/// twin toggle spring and tick, nil under Reduce Motion.
struct AttractorScreen: View {
  @State private var model = AttractorModel()
  // Sweep the horizon in 22 s at the "1×" label — half the earlier rate, which
  // read as too fast; the speed pills still show 1× as the default.
  @State private var playback = PlaybackModel(horizon: 30, sweepDuration: 22)
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  private var springAnimation: Animation? {
    reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.85)
  }

  var body: some View {
    VStack(spacing: 0) {
      stage
      controls
    }
    .background { backgroundWash }
    .navigationTitle("The Butterfly")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button {
          withAnimation(springAnimation) {
            model.reset()
          }
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
    .sensoryFeedback(.selection, trigger: model.showTwin)
    .sensoryFeedback(.impact(flexibility: .soft), trigger: model.discreteEventCount)
  }

  // MARK: - Pinned 3D stage

  private var stage: some View {
    VStack(spacing: 12) {
      sceneHost
        .frame(height: 320)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
          RoundedRectangle(cornerRadius: 24).strokeBorder(.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.25), radius: 14, y: 8)

      Text("Drag to spin it · pinch to zoom")
        .font(.caption)
        .foregroundStyle(.secondary)

      TransportBar(playback: playback, tint: Palette.attractor)

      if !model.insight.isEmpty {
        Label(model.insight, systemImage: model.showTwin ? "arrow.triangle.branch" : "sparkles")
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.leading)
          .fixedSize(horizontal: false, vertical: true)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
    .padding()
  }

  /// The 3D stage, its marker driven by a wall-clock playhead while playing and
  /// resting at the paused point otherwise.
  private var sceneHost: some View {
    Group {
      if playback.isPlaying {
        TimelineView(.animation) { context in
          AttractorSceneView(
            samples: model.samples, twinSamples: model.twinSamples,
            markerFraction: fraction(playback.playhead(at: context.date)),
            revision: model.revision)
        }
      } else {
        AttractorSceneView(
          samples: model.samples, twinSamples: model.twinSamples,
          markerFraction: playback.restingHead.map(fraction), revision: model.revision)
      }
    }
  }

  private func fraction(_ head: Double) -> Double {
    guard model.horizon > 0 else { return 0 }
    return head / model.horizon
  }

  // MARK: - Scrolling controls

  private var controls: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        presetRow
        chaosCard
        twinCard
        advancedCard
        ScienceCard(note: .lorenz)
      }
      .padding()
    }
  }

  private var presetRow: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 10) {
        ForEach(AttractorPreset.gallery) { preset in
          Button {
            withAnimation(springAnimation) {
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

  private var chaosCard: some View {
    VStack(alignment: .leading, spacing: 12) {
      Label("How wild", systemImage: "tornado")
        .font(.headline)
      ParameterSlider(
        title: "Chaos", symbol: "tornado", tint: Palette.attractor,
        range: 1...100, value: bind(\.rho))
      Text("Low settles to a steady point; high is the endless butterfly.")
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding()
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
  }

  private var twinCard: some View {
    VStack(alignment: .leading, spacing: 10) {
      Toggle(isOn: twinBinding) {
        Label("Show the twin", systemImage: "arrow.triangle.branch")
          .font(.headline)
      }
      .tint(Palette.twin)
      Text(
        "Start a second path a hair from the first, then play — watch them split apart. "
          + "That's the butterfly effect."
      )
      .font(.footnote)
      .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding()
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
  }

  private var advancedCard: some View {
    VStack(alignment: .leading, spacing: 14) {
      Label("Fine tuning", systemImage: "slider.horizontal.3")
        .font(.headline)
      ParameterSlider(
        title: "Mixing", symbol: "wind", tint: Palette.brand,
        range: 3...20, value: bind(\.sigma))
      ParameterSlider(
        title: "Settling", symbol: "arrow.down.to.line", tint: Palette.brand,
        range: 0.5...5, value: bind(\.beta))
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding()
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
  }

  private var backgroundWash: some View {
    ZStack(alignment: .top) {
      Color(uiColor: .systemGroupedBackground)
      LinearGradient(
        colors: [Palette.attractor.opacity(0.10), .clear],
        startPoint: .top, endPoint: .bottom
      )
      .frame(height: 360)
      .frame(maxWidth: .infinity, alignment: .top)
    }
    .ignoresSafeArea()
  }

  // MARK: - Bindings

  /// A binding that writes the parameter and re-integrates on every change with
  /// NO animation, so the stage tracks the slider live.
  private func bind(_ keyPath: ReferenceWritableKeyPath<AttractorModel, Double>)
    -> Binding<Double>
  {
    Binding(
      get: { model[keyPath: keyPath] },
      set: {
        model[keyPath: keyPath] = $0
        model.recompute()
      })
  }

  private var twinBinding: Binding<Bool> {
    Binding(
      get: { model.showTwin },
      set: { on in
        withAnimation(springAnimation) {
          model.setTwin(on)
        }
      })
  }
}
