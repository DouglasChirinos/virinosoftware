#!/usr/bin/env python3
"""Generate and export a pattern through the universal export flow."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PROJECT_ROOT))

from engine.generation import (
    PatternExportRequest,
    PatternGenerationRequest,
    export_generated_pattern,
)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Generate and export a garment pattern using the universal flow."
    )
    parser.add_argument(
        "--garment",
        default="falda_basica",
        help="Garment code registered in the garment registry.",
    )
    parser.add_argument(
        "--output",
        default=None,
        help="Output base name without extension.",
    )
    parser.add_argument("--waist", type=float, required=True, help="Waist in cm.")
    parser.add_argument("--hip", type=float, required=True, help="Hip in cm.")
    parser.add_argument(
        "--skirt-length",
        type=float,
        default=None,
        help="Skirt length in cm. Required by falda_basica.",
    )
    parser.add_argument(
        "--outseam",
        type=float,
        default=None,
        help="Outer pants length in cm. Required by pantalon_basico.",
    )
    parser.add_argument("--inseam", type=float, default=None, help="Optional inseam.")
    parser.add_argument("--rise", type=float, default=None, help="Optional rise.")
    parser.add_argument("--ease", type=float, default=None, help="Optional ease.")
    parser.add_argument("--hip-depth", type=float, default=None, help="Optional hip depth.")
    parser.add_argument("--no-svg", action="store_true", help="Skip SVG export.")
    parser.add_argument("--no-dxf", action="store_true", help="Skip DXF export.")
    parser.add_argument("--no-pdf", action="store_true", help="Skip PDF export.")
    return parser


def main() -> None:
    args = build_parser().parse_args()

    measurements = {
        "waist": args.waist,
        "hip": args.hip,
        "skirt_length": args.skirt_length,
        "outseam": args.outseam,
        "inseam": args.inseam,
        "rise": args.rise,
        "ease": args.ease,
        "hip_depth": args.hip_depth,
    }

    measurements = {
        key: value
        for key, value in measurements.items()
        if value is not None
    }

    output_name = args.output or args.garment

    result = export_generated_pattern(
        PatternExportRequest(
            generation_request=PatternGenerationRequest(
                garment_code=args.garment,
                measurements=measurements,
            ),
            output_name=output_name,
            export_svg=not args.no_svg,
            export_dxf=not args.no_dxf,
            export_pdf=not args.no_pdf,
        )
    )

    generation = result.generation_result

    print(f"GARMENT_CODE: {generation.garment_code}")
    print(f"GARMENT_NAME: {generation.garment_name}")
    print(f"DRAFT_CLASS: {generation.draft_class_name}")
    print(f"PIECE_COUNT: {generation.piece_count}")

    if result.svg_path:
        print(f"SVG: {result.svg_path.resolve()}")
    if result.dxf_path:
        print(f"DXF: {result.dxf_path.resolve()}")
    if result.pdf_path:
        print(f"PDF: {result.pdf_path.resolve()}")


if __name__ == "__main__":
    main()
