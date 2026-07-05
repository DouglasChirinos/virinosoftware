"""Controller for the universal GUI pattern flow."""

from __future__ import annotations

import re
import unicodedata
from dataclasses import dataclass
from datetime import datetime
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


_DEFAULT_MEASUREMENTS_BY_GARMENT: dict[str, dict[str, float]] = {
    "falda_basica": {
        "waist": 73.0,
        "hip": 99.0,
        "skirt_length": 60.0,
        "ease": 2.0,
        "hip_depth": 20.0,
    },
    "pantalon_basico": {
        "waist": 84.0,
        "hip": 104.0,
        "outseam": 100.0,
        "inseam": 76.0,
    },
    "short_basico": {
        "waist": 84.0,
        "hip": 104.0,
        "outseam": 45.0,
        "inseam": 20.0,
    },
    "falda_evase": {
        "waist": 73.0,
        "hip": 99.0,
        "skirt_length": 60.0,
        "ease": 12.0,
    },
}


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

    return sorted(options, key=lambda item: item.code)


def get_default_measurements(garment_code: str) -> dict[str, float]:
    """Return practical default measurements for MVP garments."""

    defaults = _DEFAULT_MEASUREMENTS_BY_GARMENT.get(garment_code)
    if defaults is not None:
        return dict(defaults)

    return {
        "waist": 73.0,
        "hip": 99.0,
        "skirt_length": 60.0,
    }


def slugify_output_name(value: str) -> str:
    """Return a filesystem-safe ASCII output name fragment."""

    normalized = unicodedata.normalize("NFKD", value.strip().lower())
    normalized = normalized.encode("ascii", "ignore").decode("ascii")
    normalized = re.sub(r"[^a-z0-9_-]+", "_", normalized)
    normalized = re.sub(r"_+", "_", normalized).strip("_")
    return normalized


def build_output_name(garment_code: str, pattern_name: str | None = None) -> str:
    """Return a safe GUI output name without overwriting previous exports by default."""

    garment = slugify_output_name(garment_code)
    custom = slugify_output_name(pattern_name or "")
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")

    if custom:
        return f"{garment}_{custom}_{timestamp}"

    return f"{garment}_gui_{timestamp}"


def parse_measurements(raw_values: dict[str, str]) -> dict[str, float]:
    """Parse GUI text inputs into numeric measurements."""

    parsed: dict[str, float] = {}

    for key, value in raw_values.items():
        value = value.strip()

        if not value:
            continue

        try:
            parsed[key] = float(value.replace(",", "."))
        except ValueError as exc:
            raise ValueError(f"Medida invalida para {key}: {value!r}") from exc

    return parsed


def build_generation_options(garment_code: str) -> dict[str, Any]:
    """Return generation options for GUI product behavior."""

    options: dict[str, Any] = {}

    # Producto: la falda basica debe salir completa (delantera + posterior).
    if garment_code == "falda_basica":
        options["full_pattern"] = True

    return options


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
            options=build_generation_options(garment_code),
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
                options=build_generation_options(garment_code),
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
