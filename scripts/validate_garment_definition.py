#!/usr/bin/env python3
"""Validate serializable garment JSON definitions before generation."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from engine.garments.serializable.semantic_validation import (  # noqa: E402
    validate_garment_definition_files,
)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Validate semantic contract for serializable garment JSON definitions."
    )
    parser.add_argument(
        "--definition",
        action="append",
        default=[],
        help="Path to a garment JSON definition. Can be repeated.",
    )
    parser.add_argument(
        "--definitions-dir",
        default=None,
        help="Directory containing garment JSON definitions.",
    )
    return parser


def _resolve_paths(args: argparse.Namespace) -> list[Path]:
    paths = [Path(value) for value in args.definition]
    if args.definitions_dir:
        directory = Path(args.definitions_dir)
        paths.extend(sorted(directory.glob("*.json")))
    if not paths:
        raise SystemExit("No garment definitions provided")
    return paths


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    paths = _resolve_paths(args)
    reports = validate_garment_definition_files(paths)

    for path, report in zip(paths, reports, strict=True):
        print(
            "VALID_DEFINITION: {path} code={code} measurements={measurements} "
            "pieces={pieces} formulas={formulas}".format(
                path=path,
                code=report.code,
                measurements=report.measurement_count,
                pieces=report.piece_count,
                formulas=report.formula_count,
            )
        )
        for index, piece in enumerate(report.piece_reports, start=1):
            print(
                "PIECE_{index}: {name} points={points} lines={lines} formulas={formulas}".format(
                    index=index,
                    name=piece.name,
                    points=piece.point_count,
                    lines=piece.line_count,
                    formulas=piece.formula_count,
                )
            )

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
