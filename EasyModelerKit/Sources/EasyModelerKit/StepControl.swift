/// The adaptive step-size policy for `DormandPrince`.
///
/// Accuracy is governed entirely by the tolerances through the accept test
/// (`errorNorm ≤ 1`); the scaling factors only decide how aggressively the
/// step grows or shrinks, so a run is as accurate as `relative`/`absolute`
/// demand regardless of how fast it gets there.
public struct StepControl: Sendable {
  /// Relative tolerance per component (the dominant control on smooth runs).
  public let relative: Double

  /// Absolute tolerance floor (keeps control sane as a component passes zero).
  public let absolute: Double

  /// Safety factor on the step-growth estimate (`< 1`, conventionally 0.9).
  public let safety: Double

  /// Smallest allowed step-shrink factor after a rejected step.
  public let minScale: Double

  /// Largest allowed step-growth factor after an accepted step.
  public let maxScale: Double

  public init(
    relative: Double = 1e-9,
    absolute: Double = 1e-12,
    safety: Double = 0.9,
    minScale: Double = 0.2,
    maxScale: Double = 10.0
  ) {
    self.relative = relative
    self.absolute = absolute
    self.safety = safety
    self.minScale = minScale
    self.maxScale = maxScale
  }

  /// The default policy: tight enough that the Swift engine tracks the Python
  /// reference to well inside the fidelity tolerance on the non-chaotic runs.
  public static let standard = StepControl()
}
