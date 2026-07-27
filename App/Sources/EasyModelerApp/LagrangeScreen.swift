import EasyModelerKit
import SwiftUI
import UIKit

/// The Lagrange-point playground — "Parking in Space". A live 3D stage of the
/// Earth–Moon system, pinned above a scrolling control panel so its orbit gesture
/// doesn't fight the scroll. Five satellites launch from L1–L5; the delta-v you
/// dial is a shared launch kick, and you watch which points hold their satellite
/// and which let it drift away.
///
/// Motion rules match the other screens: a slider drag re-integrates instantly (no
/// `withAnimation`), while presets and Reset spring and tick, nil under Reduce
/// Motion.
struct LagrangeScreen: View {
  @State private var model = LagrangeModel()
  @State private var playback = PlaybackModel(
    horizon: EarthMoonSystem.period * 2, sweepDuration: 18)
  @State private var spinning = true
  @State private var showTargets = true
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
    .navigationTitle("Parking in Space")
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

      TransportBar(playback: playback, tint: Palette.satellites[4])

      Label(model.insight, systemImage: "sparkles")
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.leading)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding()
  }

  private var sceneHost: some View {
    Group {
      if playback.isPlaying {
        TimelineView(.animation) { context in
          LagrangeSceneView(
            samples: model.samples,
            markerFraction: fraction(playback.playhead(at: context.date)),
            revision: model.revision, spinning: spinning, showTargets: showTargets)
        }
      } else {
        LagrangeSceneView(
          samples: model.samples,
          markerFraction: playback.restingHead.map(fraction), revision: model.revision,
          spinning: spinning, showTargets: showTargets)
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
        legend
        presetRow
        deltaVCard
        viewOptionsCard
        ScienceCard(note: .lagrange)
      }
      .padding()
    }
  }

  private var legend: some View {
    HStack(spacing: 14) {
      ForEach(Array(EarthMoonSystem.lagrangePoints.enumerated()), id: \.offset) { index, point in
        HStack(spacing: 5) {
          Circle().fill(Palette.satellites[index]).frame(width: 9, height: 9)
          Text(point.name).font(.caption).foregroundStyle(.secondary)
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var presetRow: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 10) {
        kickButton("Perfectly still", symbol: "pause.circle", kick: [0, 0, 0])
        kickButton("Gentle nudge", symbol: "wind", kick: [0, 0.02, 0.005])
        kickButton("Hard kick", symbol: "bolt", kick: [0.02, 0.02, 0.01])
      }
      .padding(.horizontal, 2)
    }
  }

  private func kickButton(_ name: String, symbol: String, kick: [Double]) -> some View {
    Button {
      withAnimation(springAnimation) {
        model.applyKick(towardMoon: kick[0], alongOrbit: kick[1], outOfPlane: kick[2])
      }
    } label: {
      Label(name, systemImage: symbol)
        .font(.subheadline)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.thinMaterial, in: Capsule())
    }
    .buttonStyle(.plain)
  }

  private var deltaVCard: some View {
    VStack(alignment: .leading, spacing: 12) {
      Label("Launch delta-v", systemImage: "paperplane")
        .font(.headline)
      ParameterSlider(
        title: "Toward Moon", symbol: "arrow.right", tint: Palette.moon,
        range: -0.05...0.05, value: bind(\.towardMoon))
      ParameterSlider(
        title: "Along orbit", symbol: "arrow.turn.right.up", tint: Palette.satellites[3],
        range: -0.05...0.05, value: bind(\.alongOrbit))
      ParameterSlider(
        title: "Out of plane", symbol: "arrow.up.and.down", tint: Palette.satellites[4],
        range: -0.05...0.05, value: bind(\.outOfPlane))
      Text("The same nudge is given to all five satellites. Can you keep any of them home?")
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding()
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
  }

  private var viewOptionsCard: some View {
    VStack(alignment: .leading, spacing: 12) {
      Label("View", systemImage: "eye")
        .font(.headline)
      Toggle(isOn: $spinning) {
        Label("Spin Earth and the Moon", systemImage: "globe")
      }
      .tint(Palette.earth)
      Toggle(isOn: $showTargets) {
        Label("Show the target rings", systemImage: "target")
      }
      .tint(Palette.satellites[3])
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding()
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
  }

  private var backgroundWash: some View {
    ZStack(alignment: .top) {
      Color(uiColor: .systemGroupedBackground)
      LinearGradient(
        colors: [Palette.earth.opacity(0.10), .clear],
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
  private func bind(_ keyPath: ReferenceWritableKeyPath<LagrangeModel, Double>) -> Binding<Double> {
    Binding(
      get: { model[keyPath: keyPath] },
      set: {
        model[keyPath: keyPath] = $0
        model.recompute()
      })
  }
}
