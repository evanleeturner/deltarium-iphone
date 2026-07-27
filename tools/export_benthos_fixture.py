#!/usr/bin/env python3
"""Export the open-benthos fidelity fixture and measure the Swift DP drift.

The phone's benthos playground model (Model B) is grounded against the tier-2
Python oracle at ``easymodeler/examples/bem_open.py``. This tool:

1. runs that oracle (scipy ``vode``) over the seasonal year to get the reference
   ``[N, B]`` trajectory, and writes it plus the temperature/salinity forcing as
   full-precision CSV fixtures the Swift Kit test loads through ``Bundle.module``;
2. reimplements the Swift ``DormandPrince`` integrator and the per-interval
   reporting driver *here*, and reports the DP-vs-vode drift envelope — the house
   parity method, run BEFORE any ``swift test`` so the Swift tolerance fence is
   measured, not guessed.

The Swift ``OpenBenthosModel`` defaults must equal the oracle's coefficients
(printed below) for the fence to mean anything.
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

from bem_open import open_benthos  # noqa: E402
from bem_open import playground_calibration  # noqa: E402
from bem_open import seasonal_year  # noqa: E402
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


def _dp_trajectory(rhs_for, y0, count, dt):
    y = list(y0)
    traj = []
    for i in range(count):
        y = _solve(rhs_for(i), i * dt, (i + 1) * dt, y)
        traj.append(list(y))
    return traj


def _write_rows(rows, path):
    with path.open("w", newline="") as handle:
        writer = csv.writer(handle, lineterminator="\n")
        for row in rows:
            writer.writerow([repr(float(v)) for v in row])


def main():
    dest = Path(__file__).resolve().parent.parent / (
        "EasyModelerKit/Tests/EasyModelerKitTests/Fixtures"
    )
    dest.mkdir(parents=True, exist_ok=True)

    driver = seasonal_year()
    cal = playground_calibration()
    frame = driver.frame
    count = len(frame)

    # tier-2 reference (scipy vode), the frozen numbers the Swift run is fenced to.
    reference = Model(open_benthos, dt=1.0).integrate(
        cal.initial, calibration=cal, timeseries=driver, dt=1.0
    )
    ref = reference.to_numpy().tolist()

    # parity: the Swift DP algorithm, same per-interval reporting convention.
    def rhs_for(i):
        row = frame.iloc[i]
        return lambda t, y: open_benthos(t, y, row, cal)

    dp = _dp_trajectory(rhs_for, cal.initial, count, 1.0)

    drift_n = max(abs(dp[i][0] - ref[i][0]) for i in range(count))
    drift_b = max(abs(dp[i][1] - ref[i][1]) for i in range(count))

    # fixtures
    _write_rows(
        [[frame["temp"].iloc[i], frame["sal"].iloc[i]] for i in range(count)],
        dest / "benthos_forcing.csv",
    )
    _write_rows(ref, dest / "benthos.csv")

    print("coefficients (Swift OpenBenthosModel defaults must match):")
    for c in cal.coefficients:
        print(f"  {c.label:8s} = {c.value}")
    print(f"  initial  = N={cal.initial[0]}, B={cal.initial[1]}")
    print(f"\nDP-vs-vode drift over {count} days:  N={drift_n:.3e}  B={drift_b:.3e}")
    print(f"wrote {dest / 'benthos.csv'} and benthos_forcing.csv ({count} rows)")


if __name__ == "__main__":
    main()
