#!/usr/bin/env python3
"""Render the app icon: the classic Lorenz attractor, the app's own butterfly.

The icon is not decoration bolted on — it is one of the app's three models drawn
honestly. This integrates the classic Lorenz system (sigma=10, rho=28, beta=8/3,
the same default the app ships) and renders its x-z projection: the two-winged
"butterfly" whose sensitive dependence on initial conditions *is* the butterfly
effect the whole system teaches. The trajectory is mirrored across the vertical
axis (the attractor's exact x -> -x symmetry) so both wings fill evenly with only
a few bold passes — legible at Home-screen and Settings sizes, where fine
filaments would vanish. Left wing prey-green, right wing predator-orange, indigo
centre; lit cores and a layered halo make it glow on the dark ground.

Writes a 1024x1024 opaque RGB PNG (App Store requires no alpha) to
App/Resources/AppIcon.png by default.
"""

from __future__ import annotations

import argparse
import io
from pathlib import Path

import cairosvg
import numpy as np
from PIL import Image

SIZE = 1024
BASE = ("#34C759", "#5E5CE6", "#FF9F0A")  # prey-green, indigo, predator-orange
CORE = ("#7BEBA0", "#A6A4FF", "#FFC65A")  # brighter lit cores
SIGMA, RHO, BETA = 10.0, 28.0, 8.0 / 3.0


def _trajectory(horizon: float, dt: float = 0.006, drop: int = 700) -> np.ndarray:
    """RK4-integrate the classic Lorenz system, discarding the transient."""

    def deriv(s: np.ndarray) -> np.ndarray:
        x, y, z = s
        return np.array([SIGMA * (y - x), x * (RHO - z) - y, x * y - BETA * z])

    s = np.array([1.0, 1.0, 1.0])
    points = []
    for i in range(int(horizon / dt) + drop):
        k1 = deriv(s)
        k2 = deriv(s + dt / 2 * k1)
        k3 = deriv(s + dt / 2 * k2)
        k4 = deriv(s + dt * k3)
        s = s + dt / 6 * (k1 + 2 * k2 + 2 * k3 + k4)
        if i >= drop:
            points.append(s.copy())
    return np.array(points)


def _svg(horizon: float = 16.0, width: float = 15.0) -> str:
    pts = _trajectory(horizon)
    a, b = pts[:, 0], pts[:, 2]  # x-z projection
    margin = 160
    scale = (SIZE - 2 * margin) / max(a.max() - a.min(), b.max() - b.min())
    px = SIZE / 2 + (a - (a.min() + a.max()) / 2) * scale
    py = SIZE / 2 - (b - (b.min() + b.max()) / 2) * scale  # flip vertical
    forward = "M " + " L ".join(f"{x:.1f},{y:.1f}" for x, y in zip(px, py))
    mirror = "M " + " L ".join(f"{SIZE - x:.1f},{y:.1f}" for x, y in zip(px, py))
    path = forward + " " + mirror  # both wings, one symmetric path

    def grad(name: str, colors: tuple[str, str, str]) -> str:
        stops = "".join(
            f'<stop offset="{o}" stop-color="{c}"/>'
            for o, c in zip((0, 0.5, 1), colors)
        )
        return f'<linearGradient id="{name}" x1="0" y1="0" x2="1" y2="0">{stops}</linearGradient>'

    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="{SIZE}" height="{SIZE}" viewBox="0 0 {SIZE} {SIZE}"><defs>
<radialGradient id="bg" cx="0.5" cy="0.42" r="0.85"><stop offset="0" stop-color="#20295C"/><stop offset="0.6" stop-color="#0E1330"/><stop offset="1" stop-color="#050712"/></radialGradient>
{grad("ln", BASE)}{grad("core", CORE)}
<filter id="g1" x="-40%" y="-40%" width="180%" height="180%"><feGaussianBlur stdDeviation="26"/></filter>
<filter id="g2" x="-40%" y="-40%" width="180%" height="180%"><feGaussianBlur stdDeviation="9"/></filter></defs>
<rect width="{SIZE}" height="{SIZE}" fill="url(#bg)"/>
<path d="{path}" fill="none" stroke="url(#ln)" stroke-width="{width * 2.6:.0f}" stroke-opacity="0.18" stroke-linecap="round" stroke-linejoin="round" filter="url(#g1)"/>
<path d="{path}" fill="none" stroke="url(#ln)" stroke-width="{width * 1.5:.0f}" stroke-opacity="0.34" stroke-linecap="round" stroke-linejoin="round" filter="url(#g2)"/>
<path d="{path}" fill="none" stroke="url(#ln)" stroke-width="{width}" stroke-opacity="1" stroke-linecap="round" stroke-linejoin="round"/>
<path d="{path}" fill="none" stroke="url(#core)" stroke-width="{width * 0.42:.1f}" stroke-opacity="0.85" stroke-linecap="round" stroke-linejoin="round"/>
</svg>"""


def main() -> None:
    default = Path(__file__).resolve().parent.parent / "App/Resources/AppIcon.png"
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, default=default, help="output PNG path")
    args = parser.parse_args()
    png = cairosvg.svg2png(
        bytestring=_svg().encode(), output_width=2 * SIZE, output_height=2 * SIZE
    )
    image = (
        Image.open(io.BytesIO(png)).convert("RGB").resize((SIZE, SIZE), Image.LANCZOS)
    )
    args.out.parent.mkdir(parents=True, exist_ok=True)
    image.save(args.out)
    print(f"wrote {args.out} ({image.size[0]}x{image.size[1]} {image.mode})")


if __name__ == "__main__":
    main()
