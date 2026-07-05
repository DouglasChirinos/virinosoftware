"""Controller for the universal GUI pattern flow."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Any

from engine.garments import list_garments
from engine.generation import (
    PatternExportRequest,
    PatternGenerationRequest,
    export_generated_pattern,
    generate_pattern,
)


@dataclass(frozen=True)
class GarmentOption:
    """GUI-friendly garment option."""

    code: str
    name: str
    required_measurements: tuple[str, ...]


@dataclass(frozen=True)
class GuiGenerationSummary:
    """Summary returned to the GUI after generation/export."""

    garment_code: str
    garment_name: str
    draft_class_name: str
    piece_count: int
    svg_path: Path | None = None
    dxf_path: Path | None = None
    pdf_path: Path | None = None


def get_garment_options() -> list[GarmentOption]:
    """Return registered garments with required measurement names."""

    options: list[GarmentOption] = []

    for garment in list_garments():
        requirements = getattr(garment.draft_class, "required_measurements", ())
        required_measurements = tuple(
            requirement.name
            for requirement in requirements
            if getattr(requirement, "required", True)
        )
        options.append(
            GarmentOption(
                code=garment.code,
                name=garment.name,
                required_measurements=required_measurements,
            )
        )

    return options


def get_default_measurements(garment_code: str) -> dict[str, float]:
    """Return practical default measurements for MVP garments."""

    if garment_code == "pantalon_basico":
        return {
            "waist": 84.0,
            "hip": 104.0,
            "outseam": 100.0,
            "inseam": 76.0,
        }

    return {
        "waist": 73.0,
        "hip": 99.0,
        "skirt_length": 60.0,
    }


def build_output_name(garment_code: str) -> str:
    """Return default GUI output name."""

    return f"{garment_code}_gui_universal"


def parse_measurements(raw_values: dict[str, str]) -> dict[str, float]:
    """Parse GUI text inputs into numeric measurements."""

    parsed: dict[str, float] = {}

    for key, value in raw_values.items():
        value = value.strip()

        if not value:
            continue

        parsed[key] = float(value.replace(",", "."))

    return parsed


def generate_summary(
    *,
    garment_code: str,
    measurements: dict[str, Any],
) -> GuiGenerationSummary:
    """Generate pattern only and return a summary."""

    result = generate_pattern(
        PatternGenerationRequest(
            garment_code=garment_code,
            measurements=measurements,
        )
    )

    return GuiGenerationSummary(
        garment_code=result.garment_code,
        garment_name=result.garment_name,
        draft_class_name=result.draft_class_name,
        piece_count=result.piece_count,
    )


def export_summary(
    *,
    garment_code: str,
    measurements: dict[str, Any],
    output_name: str | None = None,
) -> GuiGenerationSummary:
    """Generate and export pattern, then return GUI summary."""

    result = export_generated_pattern(
        PatternExportRequest(
            generation_request=PatternGenerationRequest(
                garment_code=garment_code,
                measurements=measurements,
            ),
            output_name=output_name or build_output_name(garment_code),
        )
    )

    generation = result.generation_result

    return GuiGenerationSummary(
        garment_code=generation.garment_code,
        garment_name=generation.garment_name,
        draft_class_name=generation.draft_class_name,
        piece_count=generation.piece_count,
        svg_path=result.svg_path,
        dxf_path=result.dxf_path,
        pdf_path=result.pdf_path,
    )
