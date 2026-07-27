# Fidelity fixtures

These are the tier-2 ground-truth arrays the Swift engine (tier 1) is checked
against — the frozen Python `port_reference` outputs, which are bit-exact to the
original 2016 emlib.

| File | What | Shape |
| --- | --- | --- |
| `ex1.csv` | undriven Lotka-Volterra, `[3,2]`, dt=1, 20 steps | 20 × 2 |
| `ex2.csv` | Lorenz (σ=10, ρ=99.96, β=2), `[1,1,1]`, dt=0.01, 3000 steps | 3000 × 3 |
| `ex3.csv` | food-driven Lotka-Volterra, `[3,2]`, dt=1, 241 steps | 241 × 2 |
| `food.csv` | the monthly `food` forcing series for `ex3` | 241 |
| `benthos.csv` | open benthos–nutrient run `[N,B]`, `[5,1]`, dt=1, 365 steps | 365 × 2 |
| `benthos_forcing.csv` | the seasonal `[temperature, salinity]` year driving it | 365 × 2 |
| `three_body.csv` | figure-8 choreography, three bodies, dt=0.01, two periods | 1265 × 18 |
| `lagrange.csv` | L4-launch libration, 6-D CR3BP state, dt=0.01, two periods | 1257 × 6 |
| `decay.csv` | H-bomb actinide decay chain (5 nuclides), 250,000 yr | 1200 × 5 |

## Provenance

The Lotka-Volterra / Lorenz fixtures are derived from the `easymodeler` repo
(tier 2) by `tools/export_fixtures.py`:

- source: `easymodeler/tests/fixtures/port_reference.npz` (keys `ex1`/`ex2`/`ex3`)
  and `easymodeler/tests/fixtures/LVinput.csv` (the `food` column)
- source commit: `56a34fc` (`main`)
- values written with Python `repr`, so each `float64` round-trips exactly into
  a Swift `Double`.

Regenerate whenever the tier-2 reference changes:

```
python3 tools/export_fixtures.py \
  --reference ../easymodeler/tests/fixtures/port_reference.npz \
  --forcing   ../easymodeler/tests/fixtures/LVinput.csv \
  --destination EasyModelerKit/Tests/EasyModelerKitTests/Fixtures
```

The **open benthos** fixtures (`benthos.csv`, `benthos_forcing.csv`) are the
phone playground model (Model B) — the BEM benthos with the paper's fitted
*Streblospio benedicti* coefficients (2016 paper, Table 4) opened up with a
nutrient budget. Derived by `tools/export_benthos_fixture.py` from the tier-2
oracle `easymodeler/examples/bem_open.py` (scipy `vode`), with the same tool
reimplementing the Swift Dormand–Prince integrator to report the drift envelope
(N=1.2e-4, B=8.4e-5 over the year — the parity method, run before any
`swift test`). Values written with Python `repr`. Unlike the Lotka-Volterra /
Lorenz models, this one's right-hand side uses `exp`, so it is fenced to
tolerance only, never for bit-exactness.

```
python3 tools/export_benthos_fixture.py
```

The **three-body** fixture (`three_body.csv`) is the figure-8 choreography
(Chenciner–Montgomery; Simó's initial data) integrated by the tier-2 oracle
`easymodeler/examples/three_body.py` (scipy `vode`). Its story is inverted from
the others: the Swift Dormand–Prince engine conserves energy to ~1e-10 while the
vode reference drifts ~4e-3, so their gap (2.5e-4 over the first 100 steps, 5e-2
by two periods) measures the *reference's* error. The match is therefore fenced
only early; the real fence is the conserved total energy, which the oracle plays
no part in. The initial state and masses live in
`ThreeBodyConfiguration.figureEight` (the Swift test integrates from there), so
only the trajectory is exported. `tools/export_three_body_fixture.py` also
reimplements the Swift integrator to report the drift and energy envelopes.

```
python3 tools/export_three_body_fixture.py
```

The **Lagrange** fixture (`lagrange.csv`) is a satellite launched from the
Earth–Moon L4 point with a small kick — a bounded libration in the rotating-frame
circular restricted three-body problem, from the tier-2 oracle
`easymodeler/examples/lagrange.py` (scipy `vode`). Its story is the same inversion
as the three-body's: the Swift Dormand–Prince engine conserves the **Jacobi
constant** to ~1e-15 while the vode reference drifts ~2e-6, so the match is fenced
only early (9.8e-6 over the first 200 steps) and the real fences are the Jacobi
invariant, the fact that every Lagrange point is a machine-precision equilibrium,
and the stability contrast (L4/L5 hold, L2 escapes). The μ and the five Lagrange
points live in `EarthMoonSystem`, so only the trajectory is exported.
`tools/export_lagrange_fixture.py` also reports the drift, Jacobi, and stability
envelopes.

```
python3 tools/export_lagrange_fixture.py
```

The **decay** fixture (`decay.csv`) is the H-bomb actinide chain (Pu-239 → U-235 →
Pa-231 → Ac-227 → Pb-207) — the most elaborate of the radioactive-decay chains —
integrated by the tier-2 oracle `easymodeler/examples/decay.py`. The decay-chain ODE
is linear and pure arithmetic, so most of its fences are exact and need no fixture:
atoms are conserved to ~1e-15 (decay transforms nuclei, never destroys them), and
each parent halves to `e^{-ln2}` after one half-life. This fixture pins the
multi-member ingrowth (daughters growing in as parents decay) against the engine;
the Swift DP tracks it to 1.2e-5 over the first 100 steps. The half-lives live in
`RadiationSource`, so only the trajectory is exported.
`tools/export_decay_fixture.py` also reports the drift and atom-conservation envelopes.

```
python3 tools/export_decay_fixture.py
```

Loaded in the fences through `Bundle.module` — see `FixtureLoader.swift`.
