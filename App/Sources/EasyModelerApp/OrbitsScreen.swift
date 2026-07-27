import SwiftUI
import UIKit

/// The three-body playground — "The Dance". Like the Lorenz screen, the hero is a
/// live 3D stage you orbit and pinch, pinned above a scrolling control panel so its
/// orbit gesture doesn't fight the scroll.
///
/// The front door is the stable figure-8; the headline knob makes the first star
/// heavier until the balance breaks and order slides into chaos, and the presets
/// jump to the chaotic arrangements. Motion rules match the other screens: a slider
/// drag re-integrates instantly (no `withAnimation`), while presets, Reset, and the
/// twin toggle spring and tick, nil under Reduce Motion.
struct OrbitsScreen: View {
  @State private var model = OrbitsModel()
  @State private var playback = PlaybackModel(horizon: 12.65, sweepDuration: 16)
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
    .navigationTitle("The Dance")
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

      TransportBar(playback: playback, tint: Palette.starB)

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

  /// The 3D stage, its markers driven by a wall-clock playhead while playing and
  /// resting at the paused point otherwise.
  private var sceneHost: some View {
    Group {
      if playback.isPlaying {
        TimelineView(.animation) { context in
          OrbitsSceneView(
            samples: model.samples, twinSamples: model.twinSamples,
            markerFraction: fraction(playback.playhead(at: context.date)),
            revision: model.revision)
        }
      } else {
        OrbitsSceneView(
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
        balanceCard
        twinCard
        ScienceCard(note: .threeBody)
      }
      .padding()
    }
  }

  private var presetRow: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 10) {
        ForEach(OrbitPreset.gallery) { preset in
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

  private var balanceCard: some View {
    VStack(alignment: .leading, spacing: 12) {
      Label("Off balance", systemImage: "scalemass")
        .font(.headline)
      ParameterSlider(
        title: "Heavier star", symbol: "circle.fill", tint: Palette.starA,
        range: 1...3, value: bind(\.heaviness))
      Text("Grow the first star and the tidy figure-8 unravels into chaos.")
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
        Label("Show the ghost", systemImage: "arrow.triangle.branch")
          .font(.headline)
      }
      .tint(Palette.starB)
      Text(
        "Start a second run a hair from the first. On the steady figure-8 it stays "
          + "locked; in the chaos it drifts away — the butterfly effect."
      )
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
        colors: [Palette.starC.opacity(0.12), .clear],
        startPoint: .top, endPoint: .bottom
      )
      .frame(height: 360)
      .frame(maxWidth: .infinity, alignment: .top)
    }
    .ignoresSafeArea()
  }

  // MARK: - Bindings

  /// A binding that writes the parameter and re-integrates on every change with NO
  /// animation, so the stage tracks the slider live.
  private func bind(_ keyPath: ReferenceWritableKeyPath<OrbitsModel, Double>) -> Binding<Double> {
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
