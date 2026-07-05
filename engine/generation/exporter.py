"""Universal export orchestration for generated patterns."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from types import SimpleNamespace
from typing import Any

from engine.exports.dxf.writer import export_dxf
from engine.exports.pdf.writer import export_pdf
from engine.exports.svg.writer import export_svg
from engine.generation.pattern_generator import (
    PatternGenerationRequest,
    PatternGenerationResult,
    generate_pattern,
)


class PatternExportError(Exception):
    """Raised when universal export fails."""


@dataclass(frozen=True)
class PatternExportRequest:
    """Input contract for universal pattern export."""

    generation_request: PatternGenerationRequest
    output_name: str
    export_svg: bool = True
    export_dxf: bool = True
    export_pdf: bool = True


@dataclass(frozen=True)
class PatternExportResult:
    """Output contract for universal pattern export."""

    generation_result: PatternGenerationResult
    svg_path: Path | None = None
    dxf_path: Path | None = None
    pdf_path: Path | None = None

    @property
    def exported_paths(self) -> tuple[Path, ...]:
        paths = [self.svg_path, self.dxf_path, self.pdf_path]
        return tuple(path for path in paths if path is not None)


def _normalize_point(point: Any) -> Any:
    if hasattr(point, "x") and hasattr(point, "y"):
        return point

    raise PatternExportError(f"Invalid point object: {point!r}")


def _normalize_line(line: Any) -> Any:
    if not hasattr(line, "start") or not hasattr(line, "end"):
        raise PatternExportError(f"Invalid line object: {line!r}")

    return SimpleNamespace(
        start=_normalize_point(line.start),
        end=_normalize_point(line.end),
        name=getattr(line, "name", ""),
        kind=getattr(line, "kind", "pattern"),
    )


def _normalize_piece(piece: Any) -> Any:
    if not hasattr(piece, "name"):
        raise PatternExportError(f"Piece without name cannot be exported: {piece!r}")

    if not hasattr(piece, "lines"):
        raise PatternExportError(f"Piece without lines cannot be exported: {piece!r}")

    lines = [_normalize_line(line) for line in piece.lines]

    points = {}

    for index, line in enumerate(lines, start=1):
        points[f"line_{index}_start"] = line.start
        points[f"line_{index}_end"] = line.end

    normalized = SimpleNamespace(
        name=piece.name,
        lines=lines,
        points=points,
        metadata=dict(getattr(piece, "metadata", {}) or {}),
    )

    normalized.pattern_lines = [
        line for line in lines if getattr(line, "kind", "pattern") == "pattern"
    ]
    normalized.seam_allowance_lines = [
        line for line in lines if getattr(line, "kind", "pattern") == "seam_allowance"
    ]

    return normalized


def normalize_pieces(raw_pieces: list[Any]) -> list[Any]:
    """Normalize generated pieces for the existing exporters."""

    return [_normalize_piece(piece) for piece in raw_pieces]


def _safe_output_name(output_name: str) -> str:
    safe = output_name.strip().replace(" ", "_").lower()

    if not safe:
        raise PatternExportError("output_name cannot be empty")

    return safe


def export_generated_pattern(request: PatternExportRequest) -> PatternExportResult:
    """Generate and export a pattern using the universal flow."""

    generation_result = generate_pattern(request.generation_request)
    pieces = normalize_pieces(generation_result.pieces)
    output_name = _safe_output_name(request.output_name)

    svg_path: Path | None = None
    dxf_path: Path | None = None
    pdf_path: Path | None = None

    if request.export_svg:
        svg_path = Path("exports/svg") / f"{output_name}.svg"
        svg_path.parent.mkdir(parents=True, exist_ok=True)
        export_svg(pieces, svg_path)

    if request.export_dxf:
        dxf_path = Path("exports/dxf") / f"{output_name}.dxf"
        dxf_path.parent.mkdir(parents=True, exist_ok=True)
        export_dxf(pieces, dxf_path)

    if request.export_pdf:
        pdf_path = Path("exports/pdf") / f"{output_name}.pdf"
        pdf_path.parent.mkdir(parents=True, exist_ok=True)
        export_pdf(pieces, pdf_path)

    return PatternExportResult(
        generation_result=generation_result,
        svg_path=svg_path,
        dxf_path=dxf_path,
        pdf_path=pdf_path,
    )
