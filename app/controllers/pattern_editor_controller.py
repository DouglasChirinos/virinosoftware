"""Controller for the visual pattern editor MVP.

This layer deliberately uses controlled numeric transformations instead of
free drag-and-drop. That gives traceability, reproducibility and avoids
corrupting the generated base pattern.
"""

from __future__ import annotations

import json
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Any

from engine.exports.dxf.writer import export_dxf
from engine.exports.pdf.writer import export_pdf
from engine.exports.svg.writer import export_svg
from engine.exports.structural_curves import attach_structural_curves
from engine.exports.visual_curves import attach_visual_curves
from engine.generation.exporter import (
    _arrange_pieces_for_export,
    _attach_export_metadata,
    _safe_output_name,
    normalize_pieces,
)
from engine.generation.pattern_generator import PatternGenerationRequest, PatternGenerationResult, generate_pattern
from engine.transformations import PatternVariant, TransformOperation, apply_transformations

from app.controllers.universal_pattern_controller import build_generation_options, slugify_output_name


@dataclass(frozen=True)
class EditorPatternState:
    garment_code: str
    garment_name: str
    measurements: dict[str, Any]
    pieces: list[Any]
    variant: PatternVariant
    generation_result: PatternGenerationResult


@dataclass(frozen=True)
class EditorExportSummary:
    variant_json_path: Path
    svg_path: Path | None = None
    dxf_path: Path | None = None
    pdf_path: Path | None = None


def _timestamp() -> str:
    return datetime.now().strftime("%Y%m%d_%H%M%S")


def _pattern_id(garment_code: str) -> str:
    return f"{slugify_output_name(garment_code)}_{_timestamp()}"


def _normalized_export_pieces(generation_result: PatternGenerationResult) -> list[Any]:
    pieces = normalize_pieces(generation_result.pieces)
    _arrange_pieces_for_export(pieces)
    _attach_export_metadata(pieces, generation_result)
    attach_structural_curves(pieces, generation_result.garment_code)
    attach_visual_curves(pieces, generation_result.garment_code)
    return pieces


def load_editor_pattern(
    *,
    garment_code: str,
    measurements: dict[str, Any],
    variant_name: str | None = None,
) -> EditorPatternState:
    """Generate a base pattern and open a non-destructive editable variant."""

    generation_result = generate_pattern(
        PatternGenerationRequest(
            garment_code=garment_code,
            measurements=measurements,
            options=build_generation_options(garment_code),
        )
    )
    variant = PatternVariant(
        pattern_id=_pattern_id(garment_code),
        base_garment=garment_code,
        variant_name=variant_name or f"Variante {generation_result.garment_name}",
        transformations=(),
        measurements=dict(measurements),
    )
    return EditorPatternState(
        garment_code=generation_result.garment_code,
        garment_name=generation_result.garment_name,
        measurements=dict(measurements),
        pieces=_normalized_export_pieces(generation_result),
        variant=variant,
        generation_result=generation_result,
    )


def list_piece_names(state: EditorPatternState) -> list[str]:
    return [piece.name for piece in state.pieces]


def list_point_names(state: EditorPatternState, piece_name: str) -> list[str]:
    for piece in state.pieces:
        if piece.name == piece_name:
            return sorted(piece.points.keys())
    return []


def build_move_point_operation(*, piece: str, point: str, dx: float, dy: float) -> TransformOperation:
    return TransformOperation(type="move_point", piece=piece, point=point, dx=float(dx), dy=float(dy))


def apply_editor_operation(state: EditorPatternState, operation: TransformOperation) -> EditorPatternState:
    """Return a new editor state with operation appended and applied."""

    new_variant = state.variant.append(operation)
    transformed_pieces = apply_transformations(state.pieces, new_variant.transformations)
    return EditorPatternState(
        garment_code=state.garment_code,
        garment_name=state.garment_name,
        measurements=dict(state.measurements),
        pieces=transformed_pieces,
        variant=new_variant,
        generation_result=state.generation_result,
    )


def save_variant_json(state: EditorPatternState, output_dir: Path | str = Path("variants")) -> Path:
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    safe_name = _safe_output_name(f"{state.variant.base_garment}_{slugify_output_name(state.variant.variant_name)}_{_timestamp()}")
    path = output_dir / f"{safe_name}.json"
    path.write_text(json.dumps(state.variant.to_dict(), ensure_ascii=False, indent=2), encoding="utf-8")
    return path


def export_editor_variant(
    state: EditorPatternState,
    *,
    output_name: str | None = None,
    output_dir: Path | str = Path("exports"),
    export_svg_enabled: bool = True,
    export_dxf_enabled: bool = True,
    export_pdf_enabled: bool = True,
) -> EditorExportSummary:
    """Save transformation JSON and export transformed pieces."""

    output_dir = Path(output_dir)
    variant_json_path = save_variant_json(state, output_dir=Path("variants"))
    safe_name = _safe_output_name(output_name or f"{state.variant.base_garment}_{slugify_output_name(state.variant.variant_name)}_{_timestamp()}")

    svg_path: Path | None = None
    dxf_path: Path | None = None
    pdf_path: Path | None = None

    if export_svg_enabled:
        svg_path = output_dir / "svg" / f"{safe_name}.svg"
        svg_path.parent.mkdir(parents=True, exist_ok=True)
        export_svg(state.pieces, svg_path)

    if export_dxf_enabled:
        dxf_path = output_dir / "dxf" / f"{safe_name}.dxf"
        dxf_path.parent.mkdir(parents=True, exist_ok=True)
        export_dxf(state.pieces, dxf_path)

    if export_pdf_enabled:
        pdf_path = output_dir / "pdf" / f"{safe_name}.pdf"
        pdf_path.parent.mkdir(parents=True, exist_ok=True)
        export_pdf(state.pieces, pdf_path)

    return EditorExportSummary(variant_json_path=variant_json_path, svg_path=svg_path, dxf_path=dxf_path, pdf_path=pdf_path)
