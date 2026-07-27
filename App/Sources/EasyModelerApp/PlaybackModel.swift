import Foundation
import Observation

/// Shared transport state for the model playgrounds: a wall-clock playhead that
/// sweeps a trajectory's horizon on a loop, with a speed ladder and pause. The
/// same logic drives the predator–prey time sweep and the Lorenz attractor's
/// travelling dot, so it lives here rather than being copied into each screen.
///
/// `horizon` is the trajectory span the playhead covers; a screen syncs it to
/// its model on appear so the two never drift. `sweepDuration` is the wall-clock
/// seconds to cross that span once at 1×.
@Observable
final class PlaybackModel {
  /// The trajectory span the playhead covers (seconds of model time).
  var horizon: Double
  /// Wall-clock seconds to sweep the whole horizon once at 1×.
  var sweepDuration: Double

  var speedIndex = 2
  private(set) var isPlaying = false
  private var startDate = Date()
  private var accumulated = 0.0

  /// Playback-rate ladder (× the base sweep). Index 2 (1×) is the default; the
  /// ends are a slow crawl and the fastest still-watchable sweep. Pause is the
  /// full stop, between the two speed buttons.
  let speedLevels: [Double] = [0.25, 0.5, 1, 2, 4]

  init(horizon: Double, sweepDuration: Double) {
    self.horizon = horizon
    self.sweepDuration = sweepDuration
  }

  var speedMultiplier: Double { speedLevels[speedIndex] }

  var speedText: String {
    speedMultiplier < 1 ? "\(speedMultiplier.formatted())×" : "\(Int(speedMultiplier))×"
  }

  var canSlowDown: Bool { speedIndex > 0 }
  var canSpeedUp: Bool { speedIndex < speedLevels.count - 1 }

  /// The playhead time at `date`: accumulated offset plus elapsed wall-clock,
  /// looped over the horizon so the run replays.
  func playhead(at date: Date) -> Double {
    let speed = horizon / sweepDuration * speedMultiplier
    let elapsed = date.timeIntervalSince(startDate)
    return (accumulated + elapsed * speed).truncatingRemainder(dividingBy: horizon)
  }

  /// The paused playhead position, or `nil` when nothing has played yet — for
  /// the static marker shown between sweeps.
  var restingHead: Double? { accumulated > 0.001 ? accumulated : nil }

  func toggle() {
    if isPlaying {
      accumulated = playhead(at: Date())
      isPlaying = false
    } else {
      startDate = Date()
      isPlaying = true
    }
  }

  /// Step the playback rate, rebasing the playhead first so the change doesn't
  /// jump the marker mid-sweep.
  func changeSpeed(by delta: Int) {
    let target = min(max(0, speedIndex + delta), speedLevels.count - 1)
    guard target != speedIndex else { return }
    if isPlaying {
      accumulated = playhead(at: Date())
      startDate = Date()
    }
    speedIndex = target
  }
}
