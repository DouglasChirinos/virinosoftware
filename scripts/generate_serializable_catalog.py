#!/usr/bin/env python3
"""Generate all serializable garment JSON definitions in a catalog."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from engine.garments.serializable.catalog_generation import (  # noqa: E402
    generate_serializable_catalog,
    generate_serializable_catalog_files,
)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=(
            "Generate every serializable garment JSON definition using default "
            "measurements and report generated geometry totals."
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
        reports = generate_serializable_catalog_files(args.definition)
        print(f"CATALOG_GENERATION_OK: explicit definitions={len(reports)}")
        definition_reports = reports
    else:
        catalog_report = generate_serializable_catalog(args.definitions_dir)
        print(
            "CATALOG_GENERATION_OK: {directory} definitions={definitions} "
            "generated_pieces={pieces} generated_points={points} generated_lines={lines}".format(
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
            "GENERATED_DEFINITION: {path} code={code} name={name} pieces={pieces} "
            "points={points} lines={lines} variables={variables}".format(
                path=report.path,
                code=report.code,
                name=report.name,
                pieces=report.piece_count,
                points=report.point_count,
                lines=report.line_count,
                variables=report.variable_count,
            )
        )

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
