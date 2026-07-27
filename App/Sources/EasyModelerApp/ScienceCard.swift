import SwiftUI

/// "The Science" section shown on every model screen: a paragraph on what the model
/// is and why it matters, a line on who devised the method, and the APA reference(s)
/// at the bottom. A quiet card that sits below the interactive controls.
struct ScienceCard: View {
  let note: ScienceNote

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Label("The Science", systemImage: "book.fill")
        .font(.headline)

      Text(note.summary)
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      Text(note.author)
        .font(.footnote)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      VStack(alignment: .leading, spacing: 8) {
        ForEach(note.references, id: \.self) { reference in
          Text(reference)
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
      .padding(.top, 2)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding()
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
  }
}
