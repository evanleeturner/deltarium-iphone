#!/usr/bin/env python3
"""Export the Lagrange-point fidelity fixture and measure the Swift DP drift.

The phone's Lagrange playground is grounded against the tier-2 Python oracle at
``easymodeler/examples/lagrange.py``. Like its siblings this tool:

1. runs that oracle (scipy ``vode``) over a satellite launched from L4 with a small
   kick — a bounded libration — to get the reference 6-component trajectory, and
   writes it as a full-precision CSV fixture the Swift Kit test loads;
2. reimplements the Swift ``DormandPrince`` integrator here and reports the
   DP-vs-vode drift, the Jacobi-constant conservation of the DP run, and the
   stability contrast (L4/L5 stay bounded, L2 escapes) — the house parity method,
   run BEFORE any ``swift test`` so the Swift fences are measured, not guessed.

The Swift ``EarthMoonSystem`` (μ and the five Lagrange points) must equal the
oracle's, so only the reference trajectory is exported.
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
from lagrange import MU_EARTH_MOON  # noqa: E402
from lagrange import PERIOD  # noqa: E402
from lagrange import earth_moon_calibration  # noqa: E402
from lagrange import jacobi_constant  # noqa: E402
from lagrange import lagrange_points  # noqa: E402
from lagrange import restricted_three_body  # noqa: E402

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

DIM = 6
KICK = [0.0, 0.02, 0.005]


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
    return max(abs(a[i][k] - b[i][k]) for i in range(count) for k in range(DIM))


def _max_distance(traj, point):
    return max(math.sqrt(sum((s[k] - point[k]) ** 2 for k in range(3))) for s in traj)


def main():
    dest = Path(__file__).resolve().parent.parent / (
        "EasyModelerKit/Tests/EasyModelerKitTests/Fixtures"
    )
    dest.mkdir(parents=True, exist_ok=True)

    cal = earth_moon_calibration()
    points = lagrange_points()
    dt = 0.01
    horizon = 2 * PERIOD
    count = round(horizon / dt)

    initial = points["L4"] + KICK

    # tier-2 reference (scipy vode), the frozen numbers the Swift run is fenced to.
    reference = Model(restricted_three_body, dt=dt).integrate(
        initial, maxdt=horizon, calibration=cal, dt=dt
    )
    ref = reference.to_numpy().tolist()

    # parity: the Swift DP algorithm, same per-interval reporting convention.
    dp = _dp_trajectory(
        lambda t, y: restricted_three_body(t, y, None, cal), initial, count, dt
    )

    period_steps = round(PERIOD / dt)

    c0 = jacobi_constant(initial, cal)
    dp_jacobi = max(abs(jacobi_constant(s, cal) - c0) for s in [initial, *dp])
    ref_jacobi = max(abs(jacobi_constant(s, cal) - c0) for s in [initial, *ref])

    _write_rows(ref, dest / "lagrange.csv")

    print(f"L4-launch fixture (μ = {MU_EARTH_MOON}, kick = {KICK}):")
    print(
        f"  steps = {count}   dt = {dt}   horizon = {horizon:.5f} ({horizon / PERIOD:.1f} periods)"
    )
    print("\nDP-vs-vode drift (grows as the vode reference loses accuracy):")
    for window in (50, 100, 200, 500, period_steps, count):
        print(f"  first {window:4d} steps = {_max_abs(dp, ref, window):.3e}")
    print("\nJacobi conservation (max |C - C0|):")
    print(
        f"  DP run = {dp_jacobi:.3e}   vode reference = {ref_jacobi:.3e}   (C0 = {c0:.6f})"
    )

    print("\nequilibrium residual |acceleration| at each L-point (zero velocity):")
    for name, p in points.items():
        d = restricted_three_body(0, p + [0, 0, 0], None, cal)
        print(f"  {name}: {math.sqrt(d[3] ** 2 + d[4] ** 2 + d[5] ** 2):.3e}")

    print(
        f"\nstability contrast under the same kick, DP over {horizon / PERIOD:.1f} periods:"
    )
    for name in ("L4", "L5", "L1", "L2", "L3"):
        traj = _dp_trajectory(
            lambda t, y: restricted_three_body(t, y, None, cal),
            points[name] + KICK,
            count,
            dt,
        )
        print(
            f"  {name}: max distance from point = {_max_distance([points[name] + KICK, *traj], points[name]):7.3f}"
        )

    print(f"\nwrote {dest / 'lagrange.csv'} ({count} rows)")


if __name__ == "__main__":
    main()
