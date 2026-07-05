#!/usr/bin/env python3
"""Generate a pattern directly from a serializable JSON garment definition."""

from __future__ import annotations

import argparse
from pathlib import Path
import sys


PROJECT_ROOT = Path(__file__).resolve().parents[1]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))


from engine.garments.serializable.adapter import (  # noqa: E402
    generate_serializable_pattern_from_json,
    summarize_serializable_result,
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generate a pattern from a serializable JSON garment definition."
    )
    parser.add_argument(
        "--definition",
        required=True,
        help="Path to the serializable garment JSON definition.",
    )
    parser.add_argument("--waist", type=float, default=84)
    parser.add_argument("--hip", type=float, default=104)
    parser.add_argument("--outseam", type=float, default=45)
    parser.add_argument("--inseam", type=float, default=20)
    parser.add_argument("--skirt-length", type=float, default=60)
    parser.add_argument("--ease", type=float, default=12)
    parser.add_argument("--hip-depth", type=float, default=None)
    parser.add_argument("--rise", type=float, default=None)
    return parser.parse_args()


def main() -> int:
    args = parse_args()

    measurements = {
        "waist": args.waist,
        "hip": args.hip,
        "outseam": args.outseam,
        "inseam": args.inseam,
        "skirt_length": args.skirt_length,
        "ease": args.ease,
        "hip_depth": args.hip_depth,
        "rise": args.rise,
    }
    measurements = {
        key: value
        for key, value in measurements.items()
        if value is not None
    }

    result = generate_serializable_pattern_from_json(args.definition, measurements)

    for line in summarize_serializable_result(result):
        print(line)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
