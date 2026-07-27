import SwiftUI

/// Slower · Play/Pause · Faster, styled to match the soft material aesthetic:
/// brand-tinted symbols on material circles (Play a touch larger, ringed), with
/// a live speed readout. Shared by the model playgrounds — it owns none of the
/// timing, just drives a `PlaybackModel`.
struct TransportBar: View {
  let playback: PlaybackModel
  var tint: Color = Palette.brand

  var body: some View {
    VStack(spacing: 6) {
      HStack(spacing: 26) {
        speedButton(systemImage: "tortoise.fill", delta: -1, disabled: !playback.canSlowDown)
        Button {
          playback.toggle()
        } label: {
          Image(systemName: playback.isPlaying ? "pause.fill" : "play.fill")
            .font(.title2)
            .foregroundStyle(tint)
            .frame(width: 60, height: 60)
            .background(.regularMaterial, in: Circle())
            .overlay(Circle().strokeBorder(tint.opacity(0.4), lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(playback.isPlaying ? "Pause" : "Play")
        speedButton(systemImage: "hare.fill", delta: 1, disabled: !playback.canSpeedUp)
      }
      Text("\(playback.speedText) speed")
        .font(.caption.monospacedDigit())
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity)
  }

  private func speedButton(systemImage: String, delta: Int, disabled: Bool) -> some View {
    Button {
      playback.changeSpeed(by: delta)
    } label: {
      Image(systemName: systemImage)
        .font(.title3)
        .foregroundStyle(disabled ? AnyShapeStyle(.tertiary) : AnyShapeStyle(tint))
        .frame(width: 46, height: 46)
        .background(.thinMaterial, in: Circle())
    }
    .buttonStyle(.plain)
    .disabled(disabled)
    .accessibilityLabel(delta < 0 ? "Slower" : "Faster")
  }
}
