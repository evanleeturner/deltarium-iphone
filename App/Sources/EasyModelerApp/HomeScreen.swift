import SwiftUI
import UIKit

/// The model picker, the front door that branches to each playground. Owner
/// ruling: predator and prey leads as the most approachable model, with the
/// Lorenz "butterfly" alongside it, and more models slot in here as the app
/// grows. It owns the single `NavigationStack`, so each screen it pushes is a
/// plain view.
struct HomeScreen: View {
  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 18) {
          Text("Pick a world. Nudge the sliders and watch it come alive.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)

          NavigationLink {
            PredatorPreyScreen()
          } label: {
            ModelCard(
              title: "Predator & Prey",
              blurb: "Hares and foxes chase each other in endless cycles.",
              systemImage: "hare.fill", tint: Palette.prey)
          }
          .buttonStyle(.plain)

          // Parked for a future release. The Guided Tour is still a skeleton, so
          // it stays hidden from the home screen rather than ship unfinished.
          // GuidedTourScreen.swift keeps the built progress; restore this card
          // once the step-by-step lessons are done.
          // NavigationLink {
          //   GuidedTourScreen()
          // } label: {
          //   ModelCard(
          //     title: "Guided Tour",
          //     blurb: "Learn the predator and prey equations one step at a time.",
          //     systemImage: "graduationcap.fill", tint: Palette.guide)
          // }
          // .buttonStyle(.plain)

          NavigationLink {
            AttractorScreen()
          } label: {
            ModelCard(
              title: "The Butterfly",
              blurb: "One tiny nudge, a wildly different path. Chaos you can spin in 3D.",
              systemImage: "tornado", tint: Palette.attractor)
          }
          .buttonStyle(.plain)

          NavigationLink {
            BenthosScreen()
          } label: {
            ModelCard(
              title: "The Estuary",
              blurb: "Feed a marsh and watch its life bloom and crash with the seasons.",
              systemImage: "drop.fill", tint: Palette.benthos)
          }
          .buttonStyle(.plain)

          NavigationLink {
            OrbitsScreen()
          } label: {
            ModelCard(
              title: "The Dance",
              blurb: "Three stars pull on each other in a figure-8 that tips into chaos.",
              systemImage: "point.3.connected.trianglepath.dotted", tint: Palette.starC)
          }
          .buttonStyle(.plain)

          NavigationLink {
            LagrangeScreen()
          } label: {
            ModelCard(
              title: "Parking in Space",
              blurb: "Park spacecraft at the Lagrange points, where Earth and Moon's pulls cancel.",
              systemImage: "moon.stars.fill", tint: Palette.earth)
          }
          .buttonStyle(.plain)

          NavigationLink {
            RadioactivityScreen()
          } label: {
            ModelCard(
              title: "Radioactivity",
              blurb: "How long until fallout fades? Watch decay chains dissipate over time.",
              systemImage: "atom", tint: Palette.radiation)
          }
          .buttonStyle(.plain)

          NavigationLink {
            RelativityScreen()
          } label: {
            ModelCard(
              title: "Time Dilation",
              blurb: "Fly near light speed: arrive in a few years while Earth ages for millennia.",
              systemImage: "paperplane.fill", tint: Palette.relativity)
          }
          .buttonStyle(.plain)

          NavigationLink {
            BuildScreen()
          } label: {
            ModelCard(
              title: "Build Your Own",
              blurb: "Write your own equations and watch your model come to life.",
              systemImage: "function", tint: Palette.builder)
          }
          .buttonStyle(.plain)
        }
        .padding()
      }
      .background { Color(uiColor: .systemGroupedBackground).ignoresSafeArea() }
      .navigationTitle("Deltarium")
    }
    .fontDesign(.rounded)
    .tint(Palette.brand)
  }
}

/// A tappable card for one model on the home screen: a colour-keyed glyph, a
/// name, and a one-line invitation.
private struct ModelCard: View {
  let title: String
  let blurb: String
  let systemImage: String
  let tint: Color

  var body: some View {
    HStack(spacing: 16) {
      Image(systemName: systemImage)
        .font(.title)
        .foregroundStyle(tint)
        .frame(width: 52, height: 52)
        .background(tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 14))
      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .font(.headline)
        Text(blurb)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.leading)
      }
      Spacer(minLength: 0)
      Image(systemName: "chevron.right")
        .font(.subheadline)
        .foregroundStyle(.tertiary)
    }
    .padding()
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
    .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
  }
}
