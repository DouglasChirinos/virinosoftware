#!/usr/bin/env python3
"""Generate a pattern through the universal pattern generator."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PROJECT_ROOT))

from engine.generation import PatternGenerationRequest, generate_pattern


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Generate a garment pattern using the universal generator."
    )
    parser.add_argument(
        "--garment",
        default="falda_basica",
        help="Garment code registered in the garment registry.",
    )
    parser.add_argument("--waist", type=float, required=True, help="Waist in cm.")
    parser.add_argument("--hip", type=float, required=True, help="Hip in cm.")
    parser.add_argument(
        "--skirt-length",
        type=float,
        required=True,
        help="Skirt length in cm. Required by current MVP BodyMeasurements.",
    )
    parser.add_argument("--ease", type=float, default=None, help="Optional ease in cm.")
    parser.add_argument(
        "--hip-depth",
        type=float,
        default=None,
        help="Optional hip depth in cm.",
    )
    return parser


def main() -> None:
    args = build_parser().parse_args()

    measurements = {
        "waist": args.waist,
        "hip": args.hip,
        "skirt_length": args.skirt_length,
        "ease": args.ease,
        "hip_depth": args.hip_depth,
    }

    result = generate_pattern(
        PatternGenerationRequest(
            garment_code=args.garment,
            measurements=measurements,
        )
    )

    print(f"GARMENT_CODE: {result.garment_code}")
    print(f"GARMENT_NAME: {result.garment_name}")
    print(f"DRAFT_CLASS: {result.draft_class_name}")
    print(f"PIECE_COUNT: {result.piece_count}")

    for index, piece in enumerate(result.pieces, start=1):
        piece_name = getattr(piece, "name", f"piece_{index}")
        line_count = len(getattr(piece, "lines", []))
        print(f"PIECE_{index}: {piece_name} lines={line_count}")


if __name__ == "__main__":
    main()
