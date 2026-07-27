#!/usr/bin/env python3
"""Export the three-body fidelity fixture and measure the Swift DP drift.

The phone's three-body playground is grounded against the tier-2 Python oracle at
``easymodeler/examples/three_body.py``. This tool, like its benthos sibling:

1. runs that oracle (scipy ``vode``) over the figure-8 choreography to get the
   reference 18-component trajectory, and writes it plus the initial state as
   full-precision CSV fixtures the Swift Kit test loads through ``Bundle.module``;
2. reimplements the Swift ``DormandPrince`` integrator and the reporting driver
   *here*, and reports the DP-vs-vode drift envelope and the energy conservation of
   the DP run — the house parity method, run BEFORE any ``swift test`` so the Swift
   fences are measured, not guessed.

The Swift ``ThreeBodyConfiguration.figureEight`` (masses all 1, G = 1, eps = 1e-3)
and its initial state must equal the oracle's for the fence to mean anything; the
Swift test integrates that config from its own initial state, so only the
trajectory is exported here.
"""

from __future__ import annotations

import csv
import math
import os
import sys
from pathlib import Path

_EASYMODELER = Path(
    os.environ.get(
        "EASYMODELER_PATH", Path(__file__).resolve().parents[2] / "easymodeler"
    )
)
sys.path.insert(0, str(_EASYMODELER))
sys.path.insert(0, str(_EASYMODELER / "examples"))

from easymodeler import Model  # noqa: E402
from three_body import FIGURE_EIGHT_PERIOD  # noqa: E402
from three_body import figure_eight_calibration  # noqa: E402
from three_body import pythagorean_calibration  # noqa: E402
from three_body import tangle_calibration  # noqa: E402
from three_body import three_body  # noqa: E402
from three_body import total_energy  # noqa: E402

# --- Swift DormandPrince, reimplemented to match EasyModelerKit exactly ---
C2, C3, C4, C5 = 1 / 5, 3 / 10, 4 / 5, 8 / 9
A21 = 1 / 5
A31, A32 = 3 / 40, 9 / 40
A41, A42, A43 = 44 / 45, -56 / 15, 32 / 9
A51, A52, A53, A54 = 19372 / 6561, -25360 / 2187, 64448 / 6561, -212 / 729
A61, A62, A63, A64, A65 = 9017 / 3168, -355 / 33, 46732 / 5247, 49 / 176, -5103 / 18656
B1, B3, B4, B5, B6 = 35 / 384, 500 / 1113, 125 / 192, -2187 / 6784, 11 / 84
E1, E3, E4, E5, E6, E7 = (
    71 / 57600,
    -71 / 16695,
    71 / 1920,
    -17253 / 339200,
    22 / 525,
    -1 / 40,
)
RTOL, ATOL, SAFETY, MINSCALE, MAXSCALE = 1e-9, 1e-12, 0.9, 0.2, 10.0


def _step(f, t, y, h, k1):
    n = len(y)

    def combine(terms):
        out = list(y)
        for i in range(n):
            acc = y[i]
            for w, k in terms:
                acc += h * w * k[i]
            out[i] = acc
        return out

    k2 = f(t + C2 * h, combine([(A21, k1)]))
    k3 = f(t + C3 * h, combine([(A31, k1), (A32, k2)]))
    k4 = f(t + C4 * h, combine([(A41, k1), (A42, k2), (A43, k3)]))
    k5 = f(t + C5 * h, combine([(A51, k1), (A52, k2), (A53, k3), (A54, k4)]))
    k6 = f(t + h, combine([(A61, k1), (A62, k2), (A63, k3), (A64, k4), (A65, k5)]))
    yn = [
        y[i] + h * (B1 * k1[i] + B3 * k3[i] + B4 * k4[i] + B5 * k5[i] + B6 * k6[i])
        for i in range(n)
    ]
    k7 = f(t + h, yn)
    err = [
        h
        * (E1 * k1[i] + E3 * k3[i] + E4 * k4[i] + E5 * k5[i] + E6 * k6[i] + E7 * k7[i])
        for i in range(n)
    ]
    return yn, err, k7


def _err_norm(err, ys, ye):
    total = 0.0
    for i in range(len(err)):
        scale = ATOL + RTOL * max(abs(ys[i]), abs(ye[i]))
        ratio = err[i] / scale
        total += ratio * ratio
    return math.sqrt(total / len(err))


def _scale(norm):
    return math.sqrt(math.sqrt(1.0 / norm))


def _solve(f, ta, tb, y0):
    t, y = ta, list(y0)
    k1 = f(t, y)
    h = tb - ta
    dust = (tb - ta) * 1e-12
    while t < tb - dust:
        if h > tb - t:
            h = tb - t
        yn, err, k7 = _step(f, t, y, h, k1)
        norm = _err_norm(err, y, yn)
        if norm <= 1.0:
            t, y, k1 = t + h, yn, k7
            factor = MAXSCALE if norm == 0 else min(MAXSCALE, SAFETY * _scale(norm))
            h *= factor
        else:
            h *= max(MINSCALE, SAFETY * _scale(norm))
    return y


def _dp_trajectory(rhs, y0, count, dt):
    y = list(y0)
    traj = []
    for i in range(count):
        y = _solve(rhs, i * dt, (i + 1) * dt, y)
        traj.append(list(y))
    return traj


def _write_rows(rows, path):
    with path.open("w", newline="") as handle:
        writer = csv.writer(handle, lineterminator="\n")
        for row in rows:
            writer.writerow([repr(float(v)) for v in row])


def _max_abs(a, b, count):
    return max(abs(a[i][k] - b[i][k]) for i in range(count) for k in range(18))


def main():
    dest = Path(__file__).resolve().parent.parent / (
        "EasyModelerKit/Tests/EasyModelerKitTests/Fixtures"
    )
    dest.mkdir(parents=True, exist_ok=True)

    cal = figure_eight_calibration()
    dt = 0.01
    count = round(2 * FIGURE_EIGHT_PERIOD / dt)

    # tier-2 reference (scipy vode), the frozen numbers the Swift run is fenced to.
    reference = Model(three_body, dt=dt).integrate(
        cal.initial, maxdt=2 * FIGURE_EIGHT_PERIOD, calibration=cal, dt=dt
    )
    ref = reference.to_numpy().tolist()

    # parity: the Swift DP algorithm, same per-interval reporting convention.
    dp = _dp_trajectory(
        lambda t, y: three_body(t, y, None, cal), cal.initial, count, dt
    )

    period_steps = round(FIGURE_EIGHT_PERIOD / dt)

    # energy conservation of the DP run itself — the physics invariant fence.
    energy0 = total_energy(cal.initial, cal)
    dp_drift = max(
        abs(total_energy(state, cal) - energy0) for state in [cal.initial, *dp]
    )
    ref_drift = max(
        abs(total_energy(state, cal) - energy0) for state in [cal.initial, *ref]
    )

    # periodicity: the figure-8 should return near its start after one period.
    at_period = dp[
        period_steps - 1
    ]  # dp excludes the initial state, so index i is t=(i+1)*dt
    return_gap = max(abs(at_period[k] - cal.initial[k]) for k in range(18))

    _write_rows(ref, dest / "three_body.csv")

    print("figure-8 config (Swift ThreeBodyModel must match):")
    print(f"  masses = (1, 1, 1)   G = {cal.value('G')}   eps = {cal.value('eps')}")
    print(f"  steps = {count}   dt = {dt}   horizon = {2 * FIGURE_EIGHT_PERIOD:.5f}")
    print("\nDP-vs-vode drift (grows as the vode reference loses accuracy):")
    for window in (50, 100, 200, 300, period_steps, count):
        print(f"  first {window:4d} steps = {_max_abs(dp, ref, window):.3e}")
    print("\nenergy conservation (max |E - E0|):")
    print(
        f"  DP run  = {dp_drift:.3e}   vode reference = {ref_drift:.3e}   (E0 = {energy0:.6f})"
    )
    print(f"\nfigure-8 return gap after one period (DP) = {return_gap:.3e}")
    print(f"wrote {dest / 'three_body.csv'} ({count} rows)")

    # chaotic presets: energy is conserved even in chaos — an oracle-free invariant.
    # Measure the DP energy drift and the extent over the app-scale horizon so the
    # Swift chaotic-regime fence is measured too.
    print("\nchaotic presets (DP, horizon 12, dt 0.01) — energy conservation + extent:")
    for name, chaos in (
        ("pythagorean", pythagorean_calibration()),
        ("tangle", tangle_calibration()),
    ):
        traj = _dp_trajectory(
            lambda t, y, cfg=chaos: three_body(t, y, None, cfg),
            chaos.initial,
            1200,
            0.01,
        )
        e0 = total_energy(chaos.initial, chaos)
        drift = max(
            abs(total_energy(state, chaos) - e0) for state in [chaos.initial, *traj]
        )
        extent = max(abs(state[k]) for state in traj for k in range(9))
        print(
            f"  {name:12s} max |E - E0| = {drift:.3e}   E0 = {e0:9.4f}   max |position| = {extent:6.2f}"
        )


if __name__ == "__main__":
    main()
