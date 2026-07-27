/// EasyModelerKit — the on-device ODE engine for the EasyModeler iPhone app.
///
/// This is tier 1 of the EasyModeler system (see `docs/SYSTEM_PLAN.md`): a
/// pure-Swift, offline solver a student drives with sliders. It is an
/// *approximation* of the canonical Python engine (`easymodeler`, tier 2, the
/// ground-truth reference). The fidelity contract is short-horizon agreement
/// with the Python `port_reference` fixtures to tolerance — not bit-exactness,
/// because the Swift solver is Dormand–Prince, not scipy's `vode`. Chaotic
/// systems (Lorenz) diverge past the Lyapunov time, which the app teaches as
/// the butterfly effect rather than hides.
///
/// The pieces:
/// - `DormandPrince` — the adaptive RK45 (5(4)) integrator with dense output,
///   all `+ − × ÷` / `sqrt`, so a run is bit-identical on Linux-x86 and
///   iOS-ARM.
/// - `ODESolver` — the reporting driver that mirrors the Python engine's grid
///   convention (per-interval integration, initial state excluded).
/// - `LotkaVolterraModel`, `LorenzModel`, `DrivenLotkaVolterraModel` — the
///   three canonical models, matching the tier-2 definitions.
/// - `ExpressionSystem` — wires a user's typed equations (parsed by
///   `Expression`) into the same `ODESystem`, so a student can build and run
///   their own model; pure-arithmetic systems stay bit-identical, `exp`/`pow`
///   ones carry the tolerance contract.
///
/// The fidelity of the built-in models against the frozen Python fixtures is
/// fenced in the test target — see `docs/PLAN.md`.
public enum EasyModelerKit {
  /// The semantic version of the engine surface, bumped as the API settles.
  public static let version = "0.2.0"
}
