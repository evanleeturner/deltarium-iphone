# EasyModeler — system plan

*The overall plan for the whole EasyModeler system: what it is, the two repos,
the three computation tiers, the roadmap, and the standing rulings. This is the
anchor document — read it first.*

Last updated 2026-07-25.

## What EasyModeler is

A teaching system for ordinary-differential-equation modeling. A user picks a
model (predator–prey, the Lorenz system, a time-forced model), moves its
parameters, and watches the dynamics evolve — with the honest numerics of a real
scientific solver underneath. The original was a 2016-era Python 2 library
("EasyModeler 2.2.6"); it has been modernized into a clean pandas/scipy engine
and is now growing a product front end.

## The two repos

| Repo | Role | Language | License | Visibility |
| --- | --- | --- | --- | --- |
| `easymodeler` | the engine + browser reference | Python | MIT | public |
| `deltarium-iphone` (this) | the product front end | Swift (xtool) | MIT | public |

The iPhone repo **references** the Python engine as its ground truth; it does
not fork the math casually. The two share the canonical example models
(Lotka-Volterra, Lorenz, forced Lotka-Volterra) and the frozen reference
outputs.

## The three computation tiers

The same models run at three tiers, each with a different job:

1. **On-device (tier 1, `deltarium-iphone`)** — a pure-Swift ODE engine that
   runs offline on the phone. This is the product: a kid moves sliders, the
   system re-integrates locally, the attractor redraws. It is an *approximation*
   of the Python engine.
2. **Reference / oracle (tier 2, `easymodeler`)** — the real Python package,
   pip-installable and running unchanged in the browser via JupyterLite
   (WebAssembly, no server). It is the ground truth: the phone's Swift math is
   measured against it, and it is the "math companion / helper from the website"
   a student or teacher can open to check the authoritative answer.
3. **Online follow-along (tier 3, later)** — the phone reaching out to a hosted
   copy of the real Python package (a web app, or pulling from GitHub) for
   heavier or authoritative compute, using the package as a crutch. This is a
   post-phone-build enhancement, not part of the MVP.

### The fidelity relationship (a load-bearing contract)

- The **Python** engine is *bit-exact* to the original 2016 code — proven, the
  `port_reference.npz` fixtures reproduce the old outputs to `0.0` difference.
- The **Swift** engine is *not* bit-exact to Python: its RK solver is not
  scipy's `vode`. The contract is **short-horizon agreement to tolerance** plus
  qualitative / invariant checks. Chaotic systems (Lorenz) diverge past the
  Lyapunov time no matter what — that divergence is taught as the butterfly
  effect, and tier 2 is the reference a student compares against.

## Status (2026-07-25)

- **Python engine — SHIPPED.** Phases 1–2 modernized the monolith into a clean
  pandas engine (25 test fences, CI green). Phase 3 shipped the browser
  reference layer (JupyterLite notebook + reproducible build), and fixed a
  missing pandas dependency. `easymodeler` `main` is green.
- **iPhone app — BACKBONE (this repo, just created).** Repo scaffolded, doctrine
  pulled in, `EasyModelerKit` seeded with an RK4 solver + the Lorenz model and
  contract tests (build/test/lint green), plans written. See `docs/PLAN.md`.

## Roadmap

**Python (`easymodeler`) — remaining:**

- Phase 4: provenance, flip the repo public, relist on PyPI. Prep deferrals ride
  along: the full Jupyter-doctrine pass on the notebook (jupytext pairing + a CI
  `jupyter execute` replay) and removing the dead old-API `examples/*.py`.

**iPhone (`deltarium-iphone`) — the main forward track:**

- P0 backbone (done at repo creation).
- P1 the real engine: adaptive RK45 (dense output for forcing), the three
  canonical models, and the fidelity oracle against the Python fixtures.
- P2 the app shell: SwiftUI + xtool, sliders → integrate → Swift Charts, device
  gate.
- P3 kids/real-user teaching UX, including the tier-2 "check against the truth"
  companion link.
- P4 legal spine + icon + ship (adopt LOGLINE logging).
- Later: tier 3 online follow-along.

Full detail and the open decisions are in `docs/PLAN.md`.

## Standing rulings

- **The phone is the product.** After seeing the JupyterLite reference, the owner
  ruled it "classic — ship as the backbone, but a visual dead end; an academic
  system that will never really get used." All forward development goes to the
  phone, for kids and real users. The JupyterLite backbone still ships — it is
  the engine and the tier-2 oracle — but it is not the growth area.
- **Desktop is cut.** A native desktop app was researched and dropped; the web
  need is met by the JupyterLite backbone.
- **Plotting:** matplotlib for static/publication, Plotly for interactive
  (Python side); Swift Charts on the phone.
- **Device target — iPhone only** (owner ruling 2026-07-25). "For kids and
  schools" had pulled toward iPad, but the owner does not have the toolchain
  capacity to carry an iPad target; the app is iPhone-only.

The four front-end research reports behind these rulings are at
`../.toolshed/easymodeler-docs/PHASE3_FRONTEND_*.md` (in the markdowns tree,
outside both repos).
