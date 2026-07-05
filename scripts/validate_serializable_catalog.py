#!/usr/bin/env python3
"""Validate the full serializable garment JSON catalog."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from engine.garments.serializable.catalog_quality import (  # noqa: E402
    validate_serializable_catalog,
    validate_serializable_catalog_files,
)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=(
            "Validate all serializable garment JSON definitions and run default "
            "geometry generation as a catalog quality pipeline."
        )
    )
    parser.add_argument(
        "--definitions-dir",
        default="examples/garments",
        help="Directory containing garment JSON definitions. Default: examples/garments.",
    )
    parser.add_argument(
        "--definition",
        action="append",
        default=[],
        help="Explicit garment JSON definition. Can be repeated. If provided, directory discovery is skipped.",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    if args.definition:
        reports = validate_serializable_catalog_files(args.definition)
        print(f"CATALOG_OK: explicit definitions={len(reports)}")
        definition_reports = reports
    else:
        catalog_report = validate_serializable_catalog(args.definitions_dir)
        print(
            "CATALOG_OK: {directory} definitions={definitions} generated_pieces={pieces} "
            "generated_points={points} generated_lines={lines}".format(
                directory=catalog_report.definitions_dir,
                definitions=catalog_report.definition_count,
                pieces=catalog_report.generated_piece_count,
                points=catalog_report.generated_point_count,
                lines=catalog_report.generated_line_count,
            )
        )
        definition_reports = catalog_report.definition_reports

    for report in definition_reports:
        print(
            "CATALOG_DEFINITION: {path} code={code} measurements={measurements} "
            "pieces={pieces} formulas={formulas} generated_pieces={generated_pieces} "
            "generated_points={generated_points} generated_lines={generated_lines}".format(
                path=report.path,
                code=report.code,
                measurements=report.measurement_count,
                pieces=report.piece_count,
                formulas=report.formula_count,
                generated_pieces=report.generated_piece_count,
                generated_points=report.generated_point_count,
                generated_lines=report.generated_line_count,
            )
        )

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
