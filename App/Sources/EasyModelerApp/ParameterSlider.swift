import SwiftUI

/// A labeled slider showing its live value — one tunable model parameter, in
/// plain language, keyed by a symbol and a colour to what it moves. The value
/// rolls (`numericText`) when it changes inside an animated transaction (a
/// preset or Reset) and snaps during a live drag, because a drag is never
/// wrapped in `withAnimation`.
struct ParameterSlider: View {
  let title: String
  let symbol: String
  let tint: Color
  let range: ClosedRange<Double>
  @Binding var value: Double

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 8) {
        Image(systemName: symbol)
          .font(.subheadline)
          .foregroundStyle(tint)
          .frame(width: 20)
        Text(title)
          .font(.subheadline)
        Spacer()
        Text(value, format: .number.precision(.fractionLength(2)))
          .font(.subheadline.monospacedDigit())
          .contentTransition(.numericText(value: value))
          .foregroundStyle(.secondary)
          .padding(.horizontal, 8)
          .padding(.vertical, 2)
          .background(.quaternary, in: Capsule())
      }
      Slider(value: $value, in: range)
        .tint(tint)
    }
  }
}
