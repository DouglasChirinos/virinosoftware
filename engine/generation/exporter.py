"""Universal export orchestration for generated patterns."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from types import SimpleNamespace
from typing import Any

from engine.exports.dxf.writer import export_dxf
from engine.exports.pdf.writer import export_pdf
from engine.exports.svg.writer import export_svg
from engine.exports.structural_curves import attach_structural_curves, suppress_visual_curves_when_structural
from engine.exports.visual_curves import attach_visual_curves
from engine.exports.visual_annotations import build_dimension_annotations
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
    generation_request: PatternGenerationRequest
    output_name: str
    output_dir: Path | str = Path("exports")
    export_svg: bool = True
    export_dxf: bool = True
    export_pdf: bool = True


@dataclass(frozen=True)
class PatternExportResult:
    generation_result: PatternGenerationResult
    svg_path: Path | None = None
    dxf_path: Path | None = None
    pdf_path: Path | None = None

    @property
    def exported_paths(self) -> tuple[Path, ...]:
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
    return isinstance(value, dict) and ({"x", "y"}.issubset(value.keys()) or {0, 1}.issubset(value.keys()))


def _normalize_point(point: Any) -> Point:
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
    return isinstance(line, (tuple, list)) and len(line) == 2 and isinstance(line[0], str) and isinstance(line[1], str)


def _is_serializable_line_mapping(line: Any) -> bool:
    return isinstance(line, dict) and isinstance(line.get("start"), str) and isinstance(line.get("end"), str)


def _get_serializable_point(points: dict[str, Any], point_name: str) -> Point:
    if point_name not in points:
        raise PatternExportError(f"Serializable line reference uses unknown point: {point_name!r}")
    return _normalize_point(points[point_name])


def _line_name(line: Any) -> str:
    return str(getattr(line, "name", getattr(line, "label", "")) or "")


def _line_kind(line: Any) -> str:
    return str(getattr(line, "kind", "pattern") or "pattern")


def _make_export_line(*, start: Point, end: Point, name: str = "", kind: str = "pattern") -> Any:
    return SimpleNamespace(start=start, end=end, name=name, label=name, kind=kind)


def _normalize_line(line: Any, points: dict[str, Any] | None = None) -> Any:
    if _is_serializable_line_reference(line):
        if not isinstance(points, dict):
            raise PatternExportError(f"Serializable line reference requires piece.points dict: {line!r}")
        return _make_export_line(
            start=_get_serializable_point(points, line[0]),
            end=_get_serializable_point(points, line[1]),
        )

    if _is_serializable_line_mapping(line):
        if not isinstance(points, dict):
            raise PatternExportError(f"Serializable line mapping requires piece.points dict: {line!r}")
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

    return PatternPiece(name=str(name), points=points, lines=lines, metadata=dict(metadata))


def normalize_pieces(raw_pieces: list[Any]) -> list[PatternPiece]:
    return [_normalize_piece(piece) for piece in raw_pieces]


def _measurements_as_export_dict(measurements: Any) -> dict[str, Any]:
    if isinstance(measurements, dict):
        return dict(measurements)
    as_dict = getattr(measurements, "as_dict", None)
    if callable(as_dict):
        return dict(as_dict())
    if hasattr(measurements, "__dict__"):
        return {key: value for key, value in vars(measurements).items() if not key.startswith("_") and value is not None}
    return {}


def _piece_bounds(piece: PatternPiece) -> tuple[float, float, float, float]:
    """Return bounds for one piece before visual export."""

    xs: list[float] = []
    ys: list[float] = []

    for point in piece.points.values():
        xs.append(float(point.x))
        ys.append(float(point.y))

    for line in piece.lines:
        xs.extend([float(line.start.x), float(line.end.x)])
        ys.extend([float(line.start.y), float(line.end.y)])

    if not xs or not ys:
        return (0.0, 0.0, 0.0, 0.0)

    return min(xs), min(ys), max(xs), max(ys)


def _translate_line(line: Any, dx: float, dy: float) -> Any:
    return _make_export_line(
        start=line.start.translate(dx=dx, dy=dy),
        end=line.end.translate(dx=dx, dy=dy),
        name=_line_name(line),
        kind=_line_kind(line),
    )


def _translate_piece(piece: PatternPiece, dx: float, dy: float) -> None:
    if not dx and not dy:
        return

    piece.points = {
        name: point.translate(dx=dx, dy=dy)
        for name, point in piece.points.items()
    }
    piece.lines = [_translate_line(line, dx, dy) for line in piece.lines]


def _arrange_pieces_for_export(pieces: list[PatternPiece], gutter: float = 14.0) -> None:
    """Place each piece in its own visual lane before PDF/SVG export.

    Some MVP drafts, especially pantalon_basico, generate front and back pieces
    from the same local origin. That is correct for drafting internals but wrong
    for a product-facing export because pieces and dimensions overlap. This
    layout step keeps each piece independent without changing its geometry.
    Distances remain identical because only translation is applied.
    """

    cursor_x = 0.0

    for index, piece in enumerate(pieces):
        min_x, min_y, max_x, _max_y = _piece_bounds(piece)
        width = max(max_x - min_x, 1.0)
        dx = cursor_x - min_x
        dy = -min_y
        _translate_piece(piece, dx, dy)
        piece.metadata["visual_layout_index"] = str(index)
        piece.metadata["visual_layout_dx"] = str(dx)
        piece.metadata["visual_layout_dy"] = str(dy)
        cursor_x += width + gutter


def _attach_export_metadata(pieces: list[PatternPiece], generation_result: PatternGenerationResult) -> None:
    measurements = _measurements_as_export_dict(generation_result.measurements)

    for piece in pieces:
        piece.metadata.setdefault("garment_code", generation_result.garment_code)
        piece.metadata.setdefault("garment_name", generation_result.garment_name)
        piece.metadata.setdefault("draft_class_name", generation_result.draft_class_name)
        piece.metadata.setdefault("measurements", measurements)
        piece.metadata["dimension_annotations"] = build_dimension_annotations(piece, generation_result.garment_code)


def _safe_output_name(output_name: str) -> str:
    safe = output_name.strip().replace(" ", "_").lower()
    if not safe:
        raise PatternExportError("output_name cannot be empty")
    return safe


def _export_base_dir(output_dir: Path | str) -> Path:
    return Path(output_dir)


def export_generated_pattern(request: PatternExportRequest) -> PatternExportResult:
    generation_result = generate_pattern(request.generation_request)
    pieces = normalize_pieces(generation_result.pieces)
    _arrange_pieces_for_export(pieces)
    _attach_export_metadata(pieces, generation_result)
    attach_structural_curves(pieces, generation_result.garment_code)
    attach_visual_curves(pieces, generation_result.garment_code)
    suppress_visual_curves_when_structural(pieces)
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

    return PatternExportResult(generation_result=generation_result, svg_path=svg_path, dxf_path=dxf_path, pdf_path=pdf_path)
