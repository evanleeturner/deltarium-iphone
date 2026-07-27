import EasyModelerKit
import SwiftUI
import UIKit

/// A guided, step-by-step walk through the predator–prey (Lotka-Volterra)
/// equations — the teaching path that turns the app's hallmark model into a
/// lesson. Model #2 on the home screen, right after predator–prey itself.
///
/// This is the **skeleton**: the chapter scaffold and the framing are here, so
/// the shape of the tour is settled; the interactive lesson content is still to
/// be written.
struct GuidedTourScreen: View {
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        header
        introCard
        lessonsCard
        ScienceCard(note: .lotkaVolterra)
      }
      .padding()
    }
    .background { Color(uiColor: .systemGroupedBackground).ignoresSafeArea() }
    .navigationTitle("Guided Tour")
    .navigationBarTitleDisplayMode(.inline)
    .fontDesign(.rounded)
    .tint(Palette.brand)
  }

  private var header: some View {
    HStack(spacing: 16) {
      Image(systemName: "graduationcap.fill")
        .font(.title)
        .foregroundStyle(Palette.guide)
        .frame(width: 52, height: 52)
        .background(Palette.guide.opacity(0.15), in: RoundedRectangle(cornerRadius: 14))
      VStack(alignment: .leading, spacing: 4) {
        Text("Guided Tour")
          .font(.title2.bold())
        Text("Learn the predator and prey equations one step at a time.")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }
    }
  }

  private var introCard: some View {
    VStack(alignment: .leading, spacing: 12) {
      Label("What this is", systemImage: "sparkles")
        .font(.headline)
      Text(
        "A walk through the math behind hares and foxes: what each equation says, "
          + "what every letter in it does, and how changing one number changes the whole "
          + "story. Work through it in order, or jump to the part you want."
      )
      .font(.subheadline)
      .foregroundStyle(.secondary)
      .fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding()
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
  }

  private var lessonsCard: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack {
        Label("The lessons", systemImage: "list.number")
          .font(.headline)
        Spacer()
        Text("coming soon")
          .font(.caption)
          .foregroundStyle(.secondary)
          .padding(.horizontal, 8)
          .padding(.vertical, 3)
          .background(.quaternary, in: Capsule())
      }

      ForEach(Array(Self.lessonTitles.enumerated()), id: \.offset) { index, title in
        lessonRow(number: index + 1, title: title)
      }

      Text("The lessons are being written. This is the skeleton of the tour.")
        .font(.footnote)
        .foregroundStyle(.tertiary)
        .padding(.top, 2)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding()
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
  }

  private func lessonRow(number: Int, title: String) -> some View {
    HStack(spacing: 12) {
      Text("\(number)")
        .font(.subheadline.monospacedDigit().bold())
        .foregroundStyle(Palette.guide)
        .frame(width: 28, height: 28)
        .background(Palette.guide.opacity(0.15), in: Circle())
      Text(title)
        .font(.subheadline)
      Spacer(minLength: 0)
      Image(systemName: "hourglass")
        .font(.caption)
        .foregroundStyle(.tertiary)
    }
  }

  private static let lessonTitles = [
    "Meet the hares and the foxes",
    "The two equations, in plain words",
    "What each letter does",
    "Growth, hunting, and starving",
    "Find the balance, then break it",
    "Why the cycles never quite line up",
  ]
}
