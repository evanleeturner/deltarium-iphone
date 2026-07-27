import EasyModelerKit
import SwiftUI
import UIKit

/// The relativistic-journey playground — "Time Dilation". Pick a destination and
/// a g-force; the ship flies the flip-and-burn and you watch, in 3D, the
/// spacetime worldtube fill out and the two clocks (Earth and ship) pull apart.
/// The astrophage fuel gate tells you whether you could ever carry enough to
/// stop there.
///
/// A SceneKit stage (like the Lorenz and orbit screens) pinned above a scrolling
/// control panel, on the shared transport. Sliders re-integrate instantly;
/// destination and Reset spring and tick, nil under Reduce Motion.
struct RelativityScreen: View {
  @State private var model = RelativityModel()
  @State private var playback = PlaybackModel(horizon: 4, sweepDuration: 9)
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  private var springAnimation: Animation? {
    reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.85)
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        header
        destinationCard
        stageCard
        accelerationCard
        fuelCard
        ScienceCard(note: .relativity)
      }
      .padding()
    }
    .background { backgroundWash }
    .navigationTitle("Time Dilation")
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
    .tint(Palette.relativity)
    .onAppear { playback.horizon = model.horizon }
    .onChange(of: model.horizon) { playback.horizon = model.horizon }
    .sensoryFeedback(.selection, trigger: playback.isPlaying)
    .sensoryFeedback(.selection, trigger: playback.speedIndex)
    .sensoryFeedback(.impact(flexibility: .soft), trigger: model.discreteEventCount)
  }

  // MARK: - Header

  private var header: some View {
    HStack(spacing: 16) {
      Image(systemName: "paperplane.fill")
        .font(.title)
        .foregroundStyle(Palette.relativity)
        .frame(width: 52, height: 52)
        .background(Palette.relativity.opacity(0.15), in: RoundedRectangle(cornerRadius: 14))
      VStack(alignment: .leading, spacing: 4) {
        Text("Time Dilation")
          .font(.title2.bold())
        Text("Fly near the speed of light and watch your clock fall behind Earth's.")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }
    }
  }

  // MARK: - Destination

  private var destinationCard: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Label("Destination", systemImage: "mappin.and.ellipse")
          .font(.subheadline)
        Spacer()
        Picker("Destination", selection: destinationBinding) {
          ForEach(Array(Destination.all.enumerated()), id: \.offset) { index, destination in
            Text(destination.name).tag(index)
          }
        }
        .pickerStyle(.menu)
        .tint(Palette.relativity)
      }
      Text(
        "\(model.destination.blurb) \(RelativityModel.formatDistance(model.destination.distanceLightYears)) away."
      )
      .font(.footnote)
      .foregroundStyle(.secondary)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding()
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
  }

  // MARK: - Stage + clocks

  private var stageCard: some View {
    VStack(spacing: 12) {
      animatedContent
      TransportBar(playback: playback, tint: Palette.relativity)
      Label(model.insight, systemImage: "clock.arrow.2.circlepath")
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

  private var animatedContent: some View {
    Group {
      if playback.isPlaying {
        TimelineView(.animation) { context in
          stageAndClocks(shipTime: playback.playhead(at: context.date))
        }
      } else {
        stageAndClocks(shipTime: playback.restingHead ?? 0)
      }
    }
  }

  private func stageAndClocks(shipTime: Double) -> some View {
    let now = model.sample(at: shipTime)
    // Grow the tube with the ship while playing (or after a first play); before
    // that, show the whole tube as a preview.
    let hasFlown = playback.isPlaying || playback.restingHead != nil
    let reveal = hasFlown ? model.fraction(atShipTime: shipTime) : 1.0
    return VStack(spacing: 14) {
      RelativitySceneView(
        samples: model.samples, destinationName: model.destination.name,
        revealFraction: reveal, markerFraction: model.fraction(atShipTime: shipTime),
        revision: model.revision
      )
      .frame(height: 300)
      .clipShape(RoundedRectangle(cornerRadius: 18))

      VStack(alignment: .leading, spacing: 8) {
        Text("Peak speed \(model.speedText)")
          .font(.caption)
          .foregroundStyle(.secondary)
        clockBar(
          title: "Earth", years: now.earthYears, symbol: "globe.americas.fill", tint: Palette.prey)
        clockBar(
          title: "Ship", years: now.shipYears, symbol: "paperplane.fill", tint: Palette.relativity)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(12)
      .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
  }

  /// One clock as a bar whose length is that clock's share of the (longer) Earth
  /// time, so the ship's bar always falls short — the time dilation at a glance.
  private func clockBar(title: String, years: Double, symbol: String, tint: Color) -> some View {
    let denominator = max(model.earthTimeTotal, 1e-9)
    let fraction = min(max(years / denominator, 0), 1)
    return HStack(spacing: 10) {
      Label(title, systemImage: symbol)
        .font(.caption)
        .foregroundStyle(.secondary)
        .frame(width: 66, alignment: .leading)
      GeometryReader { geometry in
        ZStack(alignment: .leading) {
          Capsule().fill(.quaternary)
          Capsule().fill(tint).frame(width: max(6, geometry.size.width * fraction))
        }
      }
      .frame(height: 12)
      Text(RelativityModel.compactYears(years))
        .font(.caption.monospacedDigit().bold())
        .foregroundStyle(tint)
        .frame(width: 74, alignment: .trailing)
    }
  }

  // MARK: - Acceleration

  private var accelerationCard: some View {
    VStack(alignment: .leading, spacing: 12) {
      ParameterSlider(
        title: "Acceleration (g)", symbol: "gauge.with.dots.needle.67percent",
        tint: Palette.relativity, range: 0.5...3, value: accelerationBinding)
      Text(
        "Top speed \(model.speedText). At the flip, time runs about \(RelativityModel.formatMultiple(model.peakGamma)) slower for the crew than for Earth."
      )
      .font(.footnote)
      .foregroundStyle(.secondary)
      .fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding()
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
  }

  // MARK: - Astrophage fuel

  private var fuelCard: some View {
    VStack(alignment: .leading, spacing: 12) {
      Label("Astrophage fuel", systemImage: "flame.fill")
        .font(.headline)

      fuelRow(
        "Packed", RelativityModel.formatMultiple(model.fuelPacked),
        tint: .secondary)
      Slider(value: fuelBinding, in: 0...21)
        .tint(Palette.relativity)
      fuelRow(
        "Needed", RelativityModel.formatMultiple(model.fuelNeeded),
        tint: model.hasEnoughFuel ? Palette.safe : .orange, bold: true)

      Label(
        model.fuelVerdict,
        systemImage: model.hasEnoughFuel ? "checkmark.seal.fill" : "exclamationmark.triangle.fill"
      )
      .font(.footnote)
      .foregroundStyle(model.hasEnoughFuel ? Palette.safe : .orange)
      .fixedSize(horizontal: false, vertical: true)
      .frame(maxWidth: .infinity, alignment: .leading)

      Text(
        "In ship-masses: the astrophage is heavier than the ship it pushes. Real fuel converts almost all its mass to light, and even that runs out fast near light speed."
      )
      .font(.caption2)
      .foregroundStyle(.tertiary)
      .fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding()
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
  }

  private func fuelRow(_ title: String, _ value: String, tint: some ShapeStyle, bold: Bool = false)
    -> some View
  {
    HStack {
      Text(title)
        .font(.subheadline)
      Spacer()
      Text("\(value) ship masses")
        .font(bold ? .subheadline.monospacedDigit().bold() : .subheadline.monospacedDigit())
        .foregroundStyle(tint)
    }
  }

  // MARK: - Bindings

  private var destinationBinding: Binding<Int> {
    Binding(
      get: { model.destinationIndex },
      set: { index in
        withAnimation(springAnimation) {
          model.selectDestination(index)
          playback.horizon = model.horizon
        }
      })
  }

  private var accelerationBinding: Binding<Double> {
    Binding(
      get: { model.gForce },
      set: {
        model.gForce = $0
        model.recompute()
      })
  }

  private var fuelBinding: Binding<Double> {
    Binding(get: { model.fuelLog }, set: { model.fuelLog = $0 })
  }

  private var backgroundWash: some View {
    ZStack(alignment: .top) {
      Color(uiColor: .systemGroupedBackground)
      LinearGradient(
        colors: [Palette.relativity.opacity(0.12), .clear],
        startPoint: .top, endPoint: .bottom
      )
      .frame(height: 340)
      .frame(maxWidth: .infinity, alignment: .top)
    }
    .ignoresSafeArea()
  }
}
