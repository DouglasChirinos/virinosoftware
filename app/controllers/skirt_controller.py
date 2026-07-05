from __future__ import annotations

from pathlib import Path

from engine.exports.svg.writer import export_svg
from engine.garments.skirt.basic import draft_basic_skirt
from engine.measurements.body import BodyMeasurements


def generate_basic_skirt_svg(
    waist: float,
    hip: float,
    skirt_length: float,
    hip_depth: float = 20.0,
    output_path: str | Path = "exports/svg/falda_basica_gui.svg",
) -> Path:
    measurements = BodyMeasurements(
        waist=waist,
        hip=hip,
        skirt_length=skirt_length,
        hip_depth=hip_depth,
    )
    pieces = draft_basic_skirt(measurements)
    return export_svg(pieces, output_path)
