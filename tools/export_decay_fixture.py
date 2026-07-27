#!/usr/bin/env python3
"""Export the decay-chain fidelity fixture and measure the Swift DP drift.

The phone's radioactivity playground is grounded against the tier-2 Python oracle at
``easymodeler/examples/decay.py``. This tool, like its siblings, freezes the most
elaborate chain — the H-bomb plutonium/uranium actinide series — and:

1. runs it through the engine (scipy ``vode``) to get the reference 5-component
   trajectory, written as a full-precision CSV the Swift Kit test loads;
2. reimplements the Swift ``DormandPrince`` integrator here and reports the
   DP-vs-vode drift and the atom conservation — the house parity method, run BEFORE
   any ``swift test`` so the Swift fences are measured, not guessed.

The Swift ``RadiationSource.hBomb`` chain (half-lives and order) must equal the
oracle's for the fence to mean anything, so only the trajectory is exported.
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

from decay import SOURCES  # noqa: E402
from decay import activity  # noqa: E402
from decay import decay_constants  # noqa: E402
from decay import initial_amounts  # noqa: E402
from decay import make_chain_rhs  # noqa: E402
from easymodeler import Model  # noqa: E402

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

CHAIN = SOURCES["hbomb"]["chains"][0]
HORIZON = SOURCES["hbomb"]["horizon"]
DIM = len(CHAIN)


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


def main():
    dest = Path(__file__).resolve().parent.parent / (
        "EasyModelerKit/Tests/EasyModelerKitTests/Fixtures"
    )
    dest.mkdir(parents=True, exist_ok=True)

    lambdas = decay_constants(CHAIN)
    rhs = make_chain_rhs(lambdas)
    initial = initial_amounts(CHAIN)
    dt = HORIZON / 1200
    count = 1200

    reference = Model(rhs, dt=dt).integrate(initial, maxdt=HORIZON, dt=dt)
    ref = reference.to_numpy().tolist()

    dp = _dp_trajectory(lambda t, y: rhs(t, y, None, None), initial, count, dt)

    whole = _max_abs(dp, ref, count)
    atoms0 = sum(initial)
    atom_drift = max(abs(sum(state) - atoms0) for state in [initial, *dp])

    _write_rows(ref, dest / "decay.csv")

    print(f"H-bomb actinide chain ({DIM} members, horizon {HORIZON:g} yr):")
    print("  members:", ", ".join(f"{m[0]}({m[1]:g}yr, w{m[2]:g})" for m in CHAIN))
    print(f"  steps = {count}   dt = {dt:g}")
    print("\nDP-vs-vode drift:")
    for window in (100, 300, 600, count):
        print(f"  first {window:4d} steps = {_max_abs(dp, ref, window):.3e}")
    print(f"\natom conservation (DP): max |Σ atoms - Σ atoms(0)| = {atom_drift:.3e}")
    print(f"whole-run DP-vs-vode = {whole:.3e}")
    a0 = activity(initial, CHAIN)
    print(
        f"activity end/start = {activity(dp[-1], CHAIN) / a0:.3e}   (a faint uranium floor)"
    )
    print(f"\nwrote {dest / 'decay.csv'} ({count} rows)")


if __name__ == "__main__":
    main()
