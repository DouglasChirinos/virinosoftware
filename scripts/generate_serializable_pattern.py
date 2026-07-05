#!/usr/bin/env python3
"""Generate a pattern from a serializable garment JSON definition."""

from __future__ import annotations

import argparse
from pathlib import Path

from engine.garments.serializable.adapter import (
    generate_serializable_pattern_from_json,
    summarize_serializable_result,
)
from engine.garments.serializable.definition import load_definition_from_json


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Generate pattern pieces from a serializable garment JSON definition."
    )
    parser.add_argument(
        "--definition",
        required=True,
        help="Path to the serializable garment JSON definition.",
    )
    parser.add_argument(
        "--measurement",
        action="append",
        default=[],
        help="Measurement override in key=value format. Can be repeated.",
    )
    return parser


def parse_measurement_pairs(pairs: list[str]) -> dict[str, float]:
    measurements: dict[str, float] = {}
    for pair in pairs:
        if "=" not in pair:
            raise SystemExit(f"Invalid --measurement '{pair}'. Expected key=value.")
        key, raw_value = pair.split("=", 1)
        key = key.strip()
        if not key:
            raise SystemExit(f"Invalid --measurement '{pair}'. Empty key.")
        try:
            measurements[key] = float(raw_value)
        except ValueError as exc:
            raise SystemExit(f"Invalid value for measurement '{key}': {raw_value}") from exc
    return measurements


def default_measurements(definition_path: Path) -> dict[str, float]:
    definition = load_definition_from_json(definition_path)
    values: dict[str, float] = {}
    for item in definition.measurements:
        if item.default is None:
            continue
        values[item.name] = float(item.default)
    return values


def main() -> None:
    parser = build_parser()
    args = parser.parse_args()

    definition_path = Path(args.definition)
    measurements = default_measurements(definition_path)
    measurements.update(parse_measurement_pairs(args.measurement))

    result = generate_serializable_pattern_from_json(definition_path, measurements)
    for line in summarize_serializable_result(result):
        print(line)


if __name__ == "__main__":
    main()
