#!/usr/bin/env python3
"""Derive the Swift fidelity fixtures from the tier-2 Python reference.

The on-device Swift engine (tier 1) is checked against the canonical Python
engine (tier 2, the `easymodeler` repo) by reproducing its frozen reference
trajectories to tolerance. This tool reads that repo's
``tests/fixtures/port_reference.npz`` (keys ``ex1``/``ex2``/``ex3``, the
bit-exact port of the original 2016 emlib) plus the ``LVinput.csv`` forcing
series, and writes plain-text CSV fixtures the Swift test target loads through
``Bundle.module``. Values are emitted with ``repr`` so each ``float64``
round-trips exactly into a Swift ``Double``.

Run it whenever the tier-2 reference changes; commit the regenerated CSVs and
note the source commit in the fixtures README.
"""

from __future__ import annotations

import argparse
import csv
import logging
from pathlib import Path

import numpy as np

logger = logging.getLogger(__name__)

# The three canonical examples, npz key -> output basename.
_TRAJECTORIES = {"ex1": "ex1", "ex2": "ex2", "ex3": "ex3"}


def _write_matrix(rows: np.ndarray, path: Path) -> None:
    """Write a 2-D array as one comma-separated line per row, exactly."""
    with path.open("w", newline="") as handle:
        writer = csv.writer(handle, lineterminator="\n")
        for row in rows:
            writer.writerow([repr(float(value)) for value in row])
    logger.info("wrote %s rows=%s cols=%s", path.name, rows.shape[0], rows.shape[1])


def _write_food(source_csv: Path, path: Path) -> None:
    """Copy the `food` column of the forcing series, one value per line."""
    with source_csv.open(newline="") as handle:
        reader = csv.DictReader(handle)
        foods = [repr(float(row["food"])) for row in reader]
    path.write_text("\n".join(foods) + "\n")
    logger.info("wrote %s values=%s", path.name, len(foods))


def export(reference_npz: Path, forcing_csv: Path, destination: Path) -> None:
    """Emit ex1/ex2/ex3 trajectories and the food forcing into `destination`."""
    destination.mkdir(parents=True, exist_ok=True)
    reference = np.load(reference_npz)
    for key, basename in _TRAJECTORIES.items():
        _write_matrix(reference[key], destination / f"{basename}.csv")
    _write_food(forcing_csv, destination / "food.csv")


def main() -> None:
    logging.basicConfig(level=logging.INFO, format="%(message)s")
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--reference",
        type=Path,
        required=True,
        help="path to the tier-2 port_reference.npz",
    )
    parser.add_argument(
        "--forcing",
        type=Path,
        required=True,
        help="path to the tier-2 LVinput.csv forcing series",
    )
    parser.add_argument(
        "--destination",
        type=Path,
        required=True,
        help="the Swift test Fixtures directory to write into",
    )
    args = parser.parse_args()
    export(args.reference, args.forcing, args.destination)


if __name__ == "__main__":
    main()
