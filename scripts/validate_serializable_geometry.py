#!/usr/bin/env python3
"""Validate generated geometry and exports for serializable garments."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))
from typing import Any

from engine.generation import PatternExportRequest, PatternGenerationRequest, export_generated_pattern
from engine.validation import compute_pattern_geometry_report, validate_exported_files


def _parse_measurements(values: list[str]) -> dict[str, float]:
    measurements: dict[str, float] = {}
    for value in values:
        if "=" not in value:
            raise SystemExit(f"Invalid measurement {value!r}; expected key=value")
        key, raw = value.split("=", 1)
        key = key.strip().replace("-", "_")
        if not key:
            raise SystemExit(f"Invalid empty measurement name in {value!r}")
        measurements[key] = float(raw)
    return measurements


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Validate serializable garment geometry and exported files."
    )
    parser.add_argument("--garment", required=True, help="Garment code to validate")
    parser.add_argument(
        "--measurement",
        action="append",
        default=[],
        help="Measurement as key=value. Can be repeated.",
    )
    parser.add_argument(
        "--output",
        default=None,
        help="Output name for exported files. Defaults to <garment>_geometry_validation.",
    )
    parser.add_argument(
        "--min-export-bytes",
        type=int,
        default=100,
        help="Minimum byte size for each exported file.",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    measurements = _parse_measurements(args.measurement)
    output_name = args.output or f"{args.garment}_geometry_validation"

    result = export_generated_pattern(
        PatternExportRequest(
            generation_request=PatternGenerationRequest(
                garment_code=args.garment,
                measurements=measurements,
            ),
            output_name=output_name,
        )
    )

    geometry_report = compute_pattern_geometry_report(
        garment_code=args.garment,
        pieces=result.generation_result.pieces,
    )
    exported_paths = validate_exported_files(
        result.exported_paths,
        min_bytes=args.min_export_bytes,
    )

    print(f"GARMENT_CODE: {geometry_report.garment_code}")
    print(f"PIECE_COUNT: {geometry_report.piece_count}")
    for index, piece_report in enumerate(geometry_report.piece_reports, start=1):
        bbox = piece_report.bounding_box
        print(
            "PIECE_{index}: {name} lines={lines} points={points} "
            "bbox=({min_x:.2f},{min_y:.2f})-({max_x:.2f},{max_y:.2f}) "
            "width={width:.2f} height={height:.2f}".format(
                index=index,
                name=piece_report.name,
                lines=piece_report.line_count,
                points=piece_report.point_count,
                min_x=bbox.min_x,
                min_y=bbox.min_y,
                max_x=bbox.max_x,
                max_y=bbox.max_y,
                width=piece_report.width,
                height=piece_report.height,
            )
        )

    for path in exported_paths:
        print(f"EXPORT_OK: {path} bytes={path.stat().st_size}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
