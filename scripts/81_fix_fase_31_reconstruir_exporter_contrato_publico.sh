#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="/home/antares/Proyecto/motor"
cd "$PROJECT_ROOT"

echo "== Fix Fase 31 #81: reconstruir exporter preservando contrato publico =="

CURRENT_BRANCH="$(git branch --show-current)"
if [[ "$CURRENT_BRANCH" != "feature/fase-31-consolidacion-contrato-exportable-serializable" ]]; then
  echo "ERROR: rama incorrecta: $CURRENT_BRANCH"
  echo "Esperada: feature/fase-31-consolidacion-contrato-exportable-serializable"
  exit 1
fi

if [[ ! -x .venv/bin/python ]]; then
  echo "ERROR: no existe .venv/bin/python. Activa/crea el entorno virtual del proyecto."
  exit 1
fi

BACKUP="engine/generation/exporter.py.fase31.fix81.bak"
cp engine/generation/exporter.py "$BACKUP"
echo "Backup creado en: $BACKUP"

cat > engine/generation/exporter.py <<'PY'
"""Universal export orchestration for generated patterns.

This module owns the public export contract used by the CLI, GUI controller,
and tests. It also normalizes serializable JSON pieces into the same exportable
shape used by traditional Python garment drafts.
"""

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
from engine.geometry.line import Line
from engine.geometry.point import Point
from engine.patterns.piece import PatternPiece


class PatternExportError(ValueError):
    """Raised when a generated pattern cannot be normalized or exported."""


@dataclass(frozen=True)
class PatternExportRequest:
    """Input contract for universal pattern export."""

    generation_request: PatternGenerationRequest
    output_name: str
    output_dir: Path | str = Path("exports")
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
        """Return generated export paths."""

        paths = (self.svg_path, self.dxf_path, self.pdf_path)
        return tuple(path for path in paths if path is not None)


def _is_point_like(value: Any) -> bool:
    return hasattr(value, "x") and hasattr(value, "y")


def _is_xy_sequence(value: Any) -> bool:
    return (
        isinstance(value, (tuple, list))
        and len(value) >= 2
        and not isinstance(value[0], str)
        and not isinstance(value[1], str)
    )


def _is_xy_mapping(value: Any) -> bool:
    return isinstance(value, dict) and (
        {"x", "y"}.issubset(value.keys()) or {0, 1}.issubset(value.keys())
    )


def _normalize_point(point: Any) -> Point:
    """Normalize point-like input into the canonical geometry ``Point``."""

    if isinstance(point, Point):
        return point

    if _is_point_like(point):
        return Point(float(point.x), float(point.y))

    if _is_xy_sequence(point):
        return Point(float(point[0]), float(point[1]))

    if _is_xy_mapping(point):
        if "x" in point and "y" in point:
            return Point(float(point["x"]), float(point["y"]))
        return Point(float(point[0]), float(point[1]))

    raise PatternExportError(f"Invalid point object: {point!r}")


def _is_serializable_line_reference(line: Any) -> bool:
    return (
        isinstance(line, (tuple, list))
        and len(line) == 2
        and isinstance(line[0], str)
        and isinstance(line[1], str)
    )


def _is_serializable_line_mapping(line: Any) -> bool:
    return (
        isinstance(line, dict)
        and isinstance(line.get("start"), str)
        and isinstance(line.get("end"), str)
    )


def _get_serializable_point(points: dict[str, Any], point_name: str) -> Point:
    if point_name not in points:
        raise PatternExportError(
            f"Serializable line reference uses unknown point: {point_name!r}"
        )

    return _normalize_point(points[point_name])


def _line_name(line: Any) -> str:
    return str(getattr(line, "name", getattr(line, "label", "")) or "")


def _line_kind(line: Any) -> str:
    return str(getattr(line, "kind", "pattern") or "pattern")


def _make_export_line(
    *,
    start: Point,
    end: Point,
    name: str = "",
    kind: str = "pattern",
) -> Any:
    """Create a line object compatible with writers and contract tests.

    Existing writers require ``start``, ``end`` and ``kind``. New serializable
    contract tests also assert ``name``. Traditional ``Line`` uses ``label``.
    A small namespace keeps both names without changing geometry primitives.
    """

    return SimpleNamespace(
        start=start,
        end=end,
        name=name,
        label=name,
        kind=kind,
    )


def _normalize_line(line: Any, points: dict[str, Any] | None = None) -> Any:
    """Normalize traditional or serializable line definitions."""

    if _is_serializable_line_reference(line):
        if not isinstance(points, dict):
            raise PatternExportError(
                f"Serializable line reference requires piece.points dict: {line!r}"
            )

        return _make_export_line(
            start=_get_serializable_point(points, line[0]),
            end=_get_serializable_point(points, line[1]),
        )

    if _is_serializable_line_mapping(line):
        if not isinstance(points, dict):
            raise PatternExportError(
                f"Serializable line mapping requires piece.points dict: {line!r}"
            )

        return _make_export_line(
            start=_get_serializable_point(points, line["start"]),
            end=_get_serializable_point(points, line["end"]),
            name=str(line.get("name", line.get("label", "")) or ""),
            kind=str(line.get("kind", "pattern") or "pattern"),
        )

    if isinstance(line, Line):
        return _make_export_line(
            start=_normalize_point(line.start),
            end=_normalize_point(line.end),
            name=getattr(line, "label", ""),
            kind=line.kind,
        )

    if not hasattr(line, "start") or not hasattr(line, "end"):
        raise PatternExportError(f"Invalid line object: {line!r}")

    return _make_export_line(
        start=_normalize_point(line.start),
        end=_normalize_point(line.end),
        name=_line_name(line),
        kind=_line_kind(line),
    )


def _normalize_source_points(raw_points: Any) -> dict[str, Point]:
    if raw_points is None:
        return {}

    if not isinstance(raw_points, dict):
        raise PatternExportError(f"Piece points must be a dict when provided: {raw_points!r}")

    return {str(name): _normalize_point(point) for name, point in raw_points.items()}


def _normalize_piece(raw_piece: Any) -> PatternPiece:
    """Normalize a generated piece into the exportable ``PatternPiece`` shape."""

    name = getattr(raw_piece, "name", None)
    raw_lines = getattr(raw_piece, "lines", None)
    raw_points = getattr(raw_piece, "points", None)
    metadata = getattr(raw_piece, "metadata", {}) or {}

    if not name:
        raise PatternExportError(f"Piece without name cannot be exported: {raw_piece!r}")

    if raw_lines is None:
        raise PatternExportError(f"Piece without lines cannot be exported: {name}")

    points = _normalize_source_points(raw_points)
    lines = [_normalize_line(line, raw_points) for line in raw_lines]

    if not points:
        for index, line in enumerate(lines, start=1):
            points[f"line_{index}_start"] = line.start
            points[f"line_{index}_end"] = line.end

    return PatternPiece(
        name=str(name),
        points=points,
        lines=lines,
        metadata=dict(metadata),
    )


def normalize_pieces(raw_pieces: list[Any]) -> list[PatternPiece]:
    """Normalize all generated pieces for export."""

    return [_normalize_piece(piece) for piece in raw_pieces]


def _safe_output_name(output_name: str) -> str:
    """Return a filesystem-safe output base name."""

    safe = output_name.strip().replace(" ", "_").lower()

    if not safe:
        raise PatternExportError("output_name cannot be empty")

    return safe


def _export_base_dir(output_dir: Path | str) -> Path:
    return Path(output_dir)


def export_generated_pattern(request: PatternExportRequest) -> PatternExportResult:
    """Generate and export a pattern using the universal flow."""

    generation_result = generate_pattern(request.generation_request)
    pieces = normalize_pieces(generation_result.pieces)
    output_name = _safe_output_name(request.output_name)
    output_dir = _export_base_dir(request.output_dir)

    svg_path: Path | None = None
    dxf_path: Path | None = None
    pdf_path: Path | None = None

    if request.export_svg:
        svg_path = output_dir / "svg" / f"{output_name}.svg"
        svg_path.parent.mkdir(parents=True, exist_ok=True)
        export_svg(pieces, svg_path)

    if request.export_dxf:
        dxf_path = output_dir / "dxf" / f"{output_name}.dxf"
        dxf_path.parent.mkdir(parents=True, exist_ok=True)
        export_dxf(pieces, dxf_path)

    if request.export_pdf:
        pdf_path = output_dir / "pdf" / f"{output_name}.pdf"
        pdf_path.parent.mkdir(parents=True, exist_ok=True)
        export_pdf(pieces, pdf_path)

    return PatternExportResult(
        generation_result=generation_result,
        svg_path=svg_path,
        dxf_path=dxf_path,
        pdf_path=pdf_path,
    )
PY

echo "== Validando sintaxis =="
.venv/bin/python -m compileall engine/generation/exporter.py

echo "== Validando contratos publicos =="
.venv/bin/python - <<'PY'
from engine.generation import (
    PatternExportError,
    PatternExportRequest,
    PatternExportResult,
    export_generated_pattern,
    normalize_pieces,
)
from engine.generation import PatternGenerationRequest

request = PatternExportRequest(
    generation_request=PatternGenerationRequest(
        garment_code="short_basico",
        measurements={"waist": 84, "hip": 104, "outseam": 45, "inseam": 20},
    ),
    output_name="contract_check",
    export_svg=False,
    export_dxf=False,
    export_pdf=False,
)
assert request.generation_request.garment_code == "short_basico"
print("OK: contratos publicos importables y PatternExportRequest compatible")
PY

echo "== Ejecutando pruebas focalizadas =="
.venv/bin/pytest -q \
  tests/test_exporter_serializable_contract.py \
  tests/test_universal_pattern_exporter.py \
  tests/test_gui_universal_controller.py

echo "== Ejecutando validaciones completas =="
make test
make export-universal-short

echo "== Estado Git =="
git status --short

echo "OK: Fix Fase 31 #81 aplicado y validado."
