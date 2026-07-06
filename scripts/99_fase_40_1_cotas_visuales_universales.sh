#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="/home/antares/Proyecto/motor"
BRANCH_NAME="feature/fase-40-gui-generacion-exportacion-serializables"

cd "$PROJECT_DIR"

echo "== Fase 40.1: cotas visuales universales por prenda =="

current_branch="$(git branch --show-current)"
if [ "$current_branch" != "$BRANCH_NAME" ]; then
  echo "ERROR: rama actual inesperada: $current_branch"
  echo "Esperado: $BRANCH_NAME"
  echo "No se aplica Fase 40.1 para evitar tocar una rama incorrecta."
  exit 1
fi

echo "== Estado Git antes de Fase 40.1 =="
git status --short

mkdir -p engine/exports/pdf engine/exports/svg engine/generation tests docs scripts

cat > engine/exports/visual_annotations.py <<'PY'
"""Visual annotation rules for pattern exports.

This module keeps product-facing dimensions out of low-level PDF/SVG writers.
The writers only render annotations. The business rule lives here:
headers show input measurements, edge dimensions show real geometry.
"""

from __future__ import annotations

import math
import re
from typing import Any, Iterable

from engine.geometry.point import Point
from engine.patterns.piece import PatternPiece

MEASUREMENT_LABELS = {
    "waist": "Cintura",
    "hip": "Cadera",
    "skirt_length": "Largo falda",
    "outseam": "Largo exterior",
    "inseam": "Entrepierna",
    "rise": "Tiro",
    "ease": "Holgura",
    "hip_depth": "Altura cadera",
    "ease_hip": "Holgura cadera",
    "ease_waist": "Holgura cintura",
}

_TECHNICAL_POINT_RE = re.compile(r"^line_\d+_(start|end)$")


def is_technical_point_name(name: str) -> bool:
    """Return True for exporter-generated point names that should not be shown."""

    return bool(_TECHNICAL_POINT_RE.match(str(name)))


def displayable_point_names(points: dict[str, Any]) -> list[str]:
    """Return point names useful enough to show to end users."""

    return [name for name in points if not is_technical_point_name(name)]


def format_number(value: float | int | Any) -> str:
    """Format centimeters without noisy trailing decimals."""

    try:
        number = float(value)
    except (TypeError, ValueError):
        return str(value)

    return f"{number:.2f}".rstrip("0").rstrip(".")


def format_measurements_for_header(measurements: dict[str, Any]) -> list[str]:
    """Return input measurements for the PDF/SVG header in Spanish."""

    lines: list[str] = []
    for key in ("waist", "hip", "skirt_length", "outseam", "inseam", "rise", "ease", "hip_depth"):
        if key in measurements and measurements[key] is not None:
            lines.append(f"{MEASUREMENT_LABELS.get(key, key)}: {format_number(measurements[key])} cm")
    return lines


def line_label(line: Any) -> str:
    """Return a normalized label/name for an export line."""

    value = getattr(line, "name", None) or getattr(line, "label", None) or ""
    return str(value).strip().lower()


def distance(start: Point, end: Point) -> float:
    return math.hypot(float(end.x) - float(start.x), float(end.y) - float(start.y))


def _dim(label: str, start: Point, end: Point, *, offset_x: float = 0.0, offset_y: float = 0.0) -> dict[str, Any]:
    return {
        "label": label,
        "start": {"x": float(start.x), "y": float(start.y)},
        "end": {"x": float(end.x), "y": float(end.y)},
        "offset": {"x": float(offset_x), "y": float(offset_y)},
    }


def _point_at(x: float, y: float) -> Point:
    return Point(float(x), float(y))


def _points_bounds(points: Iterable[Point]) -> tuple[float, float, float, float]:
    point_list = list(points)
    if not point_list:
        return (0.0, 0.0, 0.0, 0.0)
    xs = [float(point.x) for point in point_list]
    ys = [float(point.y) for point in point_list]
    return min(xs), min(ys), max(xs), max(ys)


def _line_by_label(piece: PatternPiece, expected: str) -> Any | None:
    for line in piece.lines:
        if line_label(line) == expected:
            return line
    return None


def _line_containing(piece: PatternPiece, expected: str) -> Any | None:
    for line in piece.lines:
        if expected in line_label(line):
            return line
    return None


def _basic_skirt_dimensions(piece: PatternPiece) -> list[dict[str, Any]]:
    points = piece.points
    dimensions: list[dict[str, Any]] = []

    if "A_cintura_centro" in points and "B_cintura_costado" in points:
        start = points["A_cintura_centro"]
        end = points["B_cintura_costado"]
        dimensions.append(_dim(f"Cintura pieza: {format_number(distance(start, end))} cm", start, end, offset_y=-4.0))

    if "C_cadera_centro" in points and "D_cadera_costado" in points:
        start = points["C_cadera_centro"]
        end = points["D_cadera_costado"]
        dimensions.append(_dim(f"Cadera pieza: {format_number(distance(start, end))} cm", start, end, offset_y=4.0))

    if "A_cintura_centro" in points and "E_bajo_centro" in points:
        start = points["A_cintura_centro"]
        end = points["E_bajo_centro"]
        dimensions.append(_dim(f"Largo pieza: {format_number(distance(start, end))} cm", start, end, offset_x=-4.0))

    return dimensions


def _pants_dimensions(piece: PatternPiece) -> list[dict[str, Any]]:
    dimensions: list[dict[str, Any]] = []
    points_from_lines = [line.start for line in piece.lines] + [line.end for line in piece.lines]
    min_x, min_y, max_x, max_y = _points_bounds(points_from_lines)

    waist_line = _line_by_label(piece, "cintura")
    if waist_line is not None:
        dimensions.append(
            _dim(
                f"Cintura pieza: {format_number(distance(waist_line.start, waist_line.end))} cm",
                waist_line.start,
                waist_line.end,
                offset_y=-4.0,
            )
        )

    upper_side = _line_by_label(piece, "costado_superior")
    if upper_side is not None:
        hip_start = _point_at(min_x, float(upper_side.end.y))
        hip_end = _point_at(float(upper_side.end.x), float(upper_side.end.y))
        if abs(float(hip_end.x) - float(hip_start.x)) > 0.01:
            dimensions.append(
                _dim(
                    f"Cadera pieza: {format_number(distance(hip_start, hip_end))} cm",
                    hip_start,
                    hip_end,
                    offset_y=4.0,
                )
            )

    # The current MVP pants geometry has no explicit inseam segment. The only
    # reliable vertical product dimension in geometry is total outside height.
    if max_y > min_y:
        start = _point_at(min_x, min_y)
        end = _point_at(min_x, max_y)
        dimensions.append(
            _dim(
                f"Largo exterior pieza: {format_number(distance(start, end))} cm",
                start,
                end,
                offset_x=-4.0,
            )
        )

    return dimensions


def _serializable_quad_points(piece: PatternPiece) -> tuple[Point, Point, Point, Point] | None:
    points = piece.points
    if all(name in points for name in ("A", "B", "C", "D")):
        return points["A"], points["B"], points["C"], points["D"]
    return None


def _short_dimensions(piece: PatternPiece) -> list[dict[str, Any]]:
    quad = _serializable_quad_points(piece)
    if quad is None:
        return []

    a, b, c, d = quad
    dimensions = [
        _dim(f"Cintura pieza: {format_number(distance(a, b))} cm", a, b, offset_y=-4.0),
        _dim(f"Cadera/pierna pieza: {format_number(distance(d, c))} cm", d, c, offset_y=4.0),
        _dim(f"Largo exterior pieza: {format_number(distance(a, d))} cm", a, d, offset_x=-4.0),
    ]
    return dimensions


def _evase_dimensions(piece: PatternPiece) -> list[dict[str, Any]]:
    quad = _serializable_quad_points(piece)
    if quad is None:
        return []

    a, b, c, d = quad
    _, min_y, _, max_y = _points_bounds((a, b, c, d))
    vertical_start = _point_at(float(d.x), min_y)
    vertical_end = _point_at(float(d.x), max_y)

    dimensions = [
        _dim(f"Cintura pieza: {format_number(distance(a, b))} cm", a, b, offset_y=-4.0),
        _dim(f"Bajo pieza: {format_number(distance(d, c))} cm", d, c, offset_y=4.0),
        _dim(f"Largo falda: {format_number(distance(vertical_start, vertical_end))} cm", vertical_start, vertical_end, offset_x=-4.0),
    ]
    return dimensions


def _generic_dimensions(piece: PatternPiece) -> list[dict[str, Any]]:
    """Best-effort dimensions for future simple pieces."""

    dimensions: list[dict[str, Any]] = []
    for line in piece.lines:
        label = line_label(line)
        if label in {"cintura", "bajo"}:
            product_label = "Cintura pieza" if label == "cintura" else "Bajo pieza"
            dimensions.append(
                _dim(
                    f"{product_label}: {format_number(distance(line.start, line.end))} cm",
                    line.start,
                    line.end,
                    offset_y=-4.0 if label == "cintura" else 4.0,
                )
            )
    return dimensions


def build_dimension_annotations(piece: PatternPiece, garment_code: str) -> list[dict[str, Any]]:
    """Build product-facing geometric dimensions for one piece."""

    if garment_code == "falda_basica":
        return _basic_skirt_dimensions(piece)
    if garment_code == "pantalon_basico":
        return _pants_dimensions(piece)
    if garment_code == "short_basico":
        return _short_dimensions(piece)
    if garment_code == "falda_evase":
        return _evase_dimensions(piece)
    return _generic_dimensions(piece)
PY

cat > engine/generation/exporter.py <<'PY'
"""Universal export orchestration for generated patterns."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from types import SimpleNamespace
from typing import Any

from engine.exports.dxf.writer import export_dxf
from engine.exports.pdf.writer import export_pdf
from engine.exports.svg.writer import export_svg
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
    _attach_export_metadata(pieces, generation_result)
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
PY

cat > engine/exports/pdf/writer.py <<'PY'
from __future__ import annotations

from pathlib import Path
from typing import Any, Iterable

from engine.exports.visual_annotations import displayable_point_names, format_measurements_for_header
from engine.geometry.line import Line
from engine.patterns.piece import PatternPiece


def _is_line_sequence(value: object) -> bool:
    return isinstance(value, (list, tuple)) and all(isinstance(item, Line) for item in value)


def _normalize_to_pieces(
    value: PatternPiece | list[PatternPiece] | tuple[PatternPiece, ...] | list[Line] | tuple[Line, ...],
) -> list[PatternPiece]:
    if isinstance(value, PatternPiece):
        return [value]
    if _is_line_sequence(value):
        return [PatternPiece(name="Lineas exportadas", lines=list(value))]
    return list(value)  # type: ignore[arg-type]


def _iter_lines(pieces: Iterable[PatternPiece]) -> Iterable[Any]:
    for piece in pieces:
        yield from piece.lines


def _canvas_bounds(pieces: list[PatternPiece]) -> tuple[float, float, float, float]:
    xs: list[float] = []
    ys: list[float] = []

    for line in _iter_lines(pieces):
        xs.extend([float(line.start.x), float(line.end.x)])
        ys.extend([float(line.start.y), float(line.end.y)])

    for piece in pieces:
        for point in piece.points.values():
            xs.append(float(point.x))
            ys.append(float(point.y))
        for dim in (piece.metadata or {}).get("dimension_annotations", []):
            for key in ("start", "end"):
                point = dim.get(key, {})
                offset = dim.get("offset", {})
                xs.append(float(point.get("x", 0.0)) + float(offset.get("x", 0.0)))
                ys.append(float(point.get("y", 0.0)) + float(offset.get("y", 0.0)))

    if not xs or not ys:
        return (0.0, 0.0, 10.0, 10.0)
    return (min(xs), min(ys), max(xs), max(ys))


def _garment_payload(pieces: list[PatternPiece]) -> tuple[str, str, dict[str, Any]]:
    for piece in pieces:
        metadata = getattr(piece, "metadata", {}) or {}
        code = str(metadata.get("garment_code", "") or "")
        name = str(metadata.get("garment_name", "") or "")
        measurements = metadata.get("measurements") if isinstance(metadata.get("measurements"), dict) else {}
        if code or name or measurements:
            return code, name, measurements
    return "", "", {}


def _draw_wrapped_line(canvas: Any, *, text: str, x: float, y: float, max_chars: int = 100, leading: float = 11.0) -> float:
    chunks = [text[index : index + max_chars] for index in range(0, len(text), max_chars)] or [""]
    for chunk in chunks:
        canvas.drawString(x, y, chunk)
        y -= leading
    return y


def _overlaps(box: tuple[float, float, float, float], boxes: list[tuple[float, float, float, float]]) -> bool:
    left, bottom, right, top = box
    for other_left, other_bottom, other_right, other_top in boxes:
        if not (right < other_left or left > other_right or top < other_bottom or bottom > other_top):
            return True
    return False


def _label_position(*, x: float, y: float, text: str, font_size: float, occupied: list[tuple[float, float, float, float]]) -> tuple[float, float]:
    width = max(18.0, len(text) * font_size * 0.52)
    height = font_size + 2.0
    offsets = [(5, 5), (5, -10), (-width - 5, 5), (-width - 5, -10), (0, 14), (0, -18), (12, 14), (12, -18)]
    for dx, dy in offsets:
        label_x = x + dx
        label_y = y + dy
        box = (label_x, label_y - 2, label_x + width, label_y + height)
        if not _overlaps(box, occupied):
            occupied.append(box)
            return label_x, label_y
    label_x = x + 5
    label_y = y - 24 - (len(occupied) % 5) * (height + 2)
    occupied.append((label_x, label_y - 2, label_x + width, label_y + height))
    return label_x, label_y


def _draw_dimension(canvas: Any, tx: Any, ty: Any, dim: dict[str, Any]) -> None:
    start = dim.get("start", {})
    end = dim.get("end", {})
    offset = dim.get("offset", {})
    label = str(dim.get("label", "") or "")

    sx = float(start.get("x", 0.0))
    sy = float(start.get("y", 0.0))
    ex = float(end.get("x", 0.0))
    ey = float(end.get("y", 0.0))
    ox = float(offset.get("x", 0.0))
    oy = float(offset.get("y", 0.0))

    x1 = tx(sx)
    y1 = ty(sy)
    x2 = tx(ex)
    y2 = ty(ey)
    dx1 = tx(sx + ox)
    dy1 = ty(sy + oy)
    dx2 = tx(ex + ox)
    dy2 = ty(ey + oy)

    canvas.setDash(2, 2)
    canvas.setLineWidth(0.6)
    canvas.line(x1, y1, dx1, dy1)
    canvas.line(x2, y2, dx2, dy2)
    canvas.line(dx1, dy1, dx2, dy2)
    canvas.setDash()
    mid_x = (dx1 + dx2) / 2
    mid_y = (dy1 + dy2) / 2
    canvas.setFont("Helvetica", 7)
    canvas.drawString(mid_x + 3, mid_y + 3, label)


def export_pdf(
    pieces: PatternPiece | list[PatternPiece] | tuple[PatternPiece, ...] | list[Line] | tuple[Line, ...],
    output_path: str | Path,
) -> Path:
    try:
        from reportlab.lib.pagesizes import A4
        from reportlab.pdfgen import canvas
    except ImportError as exc:
        raise RuntimeError("Falta reportlab. Ejecuta: python3 -m pip install -r requirements.txt") from exc

    normalized = _normalize_to_pieces(pieces)
    output = Path(output_path)
    output.parent.mkdir(parents=True, exist_ok=True)

    c = canvas.Canvas(str(output), pagesize=A4)
    page_width, page_height = A4

    margin = 36.0
    header_y = page_height - margin
    metadata_y = header_y - 18
    pattern_top = metadata_y - 52

    garment_code, garment_name, measurements = _garment_payload(normalized)
    measurement_lines = format_measurements_for_header(measurements)

    c.setFont("Helvetica-Bold", 12)
    c.drawString(margin, header_y, "Motor Patronaje 2D - Exportacion")

    c.setFont("Helvetica", 8)
    if garment_code or garment_name:
        metadata_y = _draw_wrapped_line(c, text=f"Prenda: {(garment_code + ' - ' + garment_name).strip(' -')}", x=margin, y=metadata_y)
    if measurement_lines:
        metadata_y = _draw_wrapped_line(c, text="Medidas: " + " | ".join(measurement_lines), x=margin, y=metadata_y)
    piece_names = ", ".join(piece.name for piece in normalized)
    metadata_y = _draw_wrapped_line(c, text="Piezas: " + piece_names, x=margin, y=metadata_y)
    pattern_top = min(pattern_top, metadata_y - 14)

    min_x, min_y, max_x, max_y = _canvas_bounds(normalized)
    pattern_width = max(max_x - min_x, 1.0)
    pattern_height = max(max_y - min_y, 1.0)
    available_width = page_width - 2 * margin
    available_height = max(pattern_top - margin, 120.0)
    scale = min(8.0, available_width / pattern_width, available_height / pattern_height)

    def tx(x_value: float) -> float:
        return margin + (x_value - min_x) * scale

    def ty(y_value: float) -> float:
        return margin + (max_y - y_value) * scale

    for piece in normalized:
        for line in piece.lines:
            x1 = tx(float(line.start.x))
            y1 = ty(float(line.start.y))
            x2 = tx(float(line.end.x))
            y2 = ty(float(line.end.y))
            if line.kind == "seam_allowance":
                c.setDash(4, 3)
                c.setLineWidth(0.7)
            elif line.kind == "helper":
                c.setDash(2, 3)
                c.setLineWidth(0.6)
            else:
                c.setDash()
                c.setLineWidth(1.0)
            c.line(x1, y1, x2, y2)

        piece_points = list(piece.points.values())
        if piece_points:
            piece_min_x = min(float(point.x) for point in piece_points)
            piece_max_y = max(float(point.y) for point in piece_points)
            c.setFont("Helvetica-Bold", 8)
            c.drawString(tx(piece_min_x), ty(piece_max_y) - 12, piece.name)

        for dim in (piece.metadata or {}).get("dimension_annotations", []):
            _draw_dimension(c, tx, ty, dim)

        names_to_show = displayable_point_names(piece.points)
        if names_to_show:
            c.setDash()
            c.setFont("Helvetica", 6.8)
            occupied: list[tuple[float, float, float, float]] = []
            for name in sorted(names_to_show, key=lambda item: (float(piece.points[item].y), float(piece.points[item].x), item)):
                point = piece.points[name]
                x = tx(float(point.x))
                y = ty(float(point.y))
                c.circle(x, y, 1.2, stroke=1, fill=1)
                label_x, label_y = _label_position(x=x, y=y, text=name, font_size=6.8, occupied=occupied)
                c.drawString(label_x, label_y, name)

    c.showPage()
    c.save()
    return output
PY

cat > engine/exports/svg/writer.py <<'PY'
from __future__ import annotations

from pathlib import Path
from typing import Any, Iterable
from xml.sax.saxutils import escape

from engine.exports.visual_annotations import displayable_point_names, format_measurements_for_header
from engine.geometry.line import Line
from engine.patterns.piece import PatternPiece


def _is_line_sequence(value: object) -> bool:
    return isinstance(value, (list, tuple)) and all(isinstance(item, Line) for item in value)


def _normalize_to_pieces(
    value: PatternPiece | list[PatternPiece] | tuple[PatternPiece, ...] | list[Line] | tuple[Line, ...],
) -> list[PatternPiece]:
    if isinstance(value, PatternPiece):
        return [value]
    if _is_line_sequence(value):
        return [PatternPiece(name="Lineas exportadas", lines=list(value))]
    return list(value)  # type: ignore[arg-type]


def _iter_lines(pieces: Iterable[PatternPiece]) -> Iterable[Any]:
    for piece in pieces:
        yield from piece.lines


def _canvas_bounds(pieces: list[PatternPiece], margin: float = 20.0) -> tuple[float, float, float, float]:
    xs: list[float] = []
    ys: list[float] = []

    for line in _iter_lines(pieces):
        xs.extend([float(line.start.x), float(line.end.x)])
        ys.extend([float(line.start.y), float(line.end.y)])

    for piece in pieces:
        for point in piece.points.values():
            xs.append(float(point.x))
            ys.append(float(point.y))
        for dim in (piece.metadata or {}).get("dimension_annotations", []):
            for key in ("start", "end"):
                point = dim.get(key, {})
                offset = dim.get("offset", {})
                xs.append(float(point.get("x", 0.0)) + float(offset.get("x", 0.0)))
                ys.append(float(point.get("y", 0.0)) + float(offset.get("y", 0.0)))

    if not xs or not ys:
        return (0.0, 0.0, 200.0, 200.0)
    return min(xs) - margin, min(ys) - margin, max(xs) + margin, max(ys) + margin


def _dash(line: Any) -> str:
    if line.kind == "seam_allowance":
        return ' stroke-dasharray="8 5"'
    if line.kind == "helper":
        return ' stroke-dasharray="3 4"'
    return ""


def _garment_payload(pieces: list[PatternPiece]) -> tuple[str, str, dict[str, Any]]:
    for piece in pieces:
        metadata = getattr(piece, "metadata", {}) or {}
        code = str(metadata.get("garment_code", "") or "")
        name = str(metadata.get("garment_name", "") or "")
        measurements = metadata.get("measurements") if isinstance(metadata.get("measurements"), dict) else {}
        if code or name or measurements:
            return code, name, measurements
    return "", "", {}


def _overlaps(box: tuple[float, float, float, float], boxes: list[tuple[float, float, float, float]]) -> bool:
    left, top, right, bottom = box
    for other_left, other_top, other_right, other_bottom in boxes:
        if not (right < other_left or left > other_right or bottom < other_top or top > other_bottom):
            return True
    return False


def _label_position(*, x: float, y: float, text: str, font_size: float, occupied: list[tuple[float, float, float, float]]) -> tuple[float, float]:
    width = max(35.0, len(text) * font_size * 0.58)
    height = font_size + 4.0
    offsets = [(6, -6), (6, 14), (-width - 6, -6), (-width - 6, 14), (0, -22), (0, 28), (16, -22), (16, 28)]
    for dx, dy in offsets:
        label_x = x + dx
        label_y = y + dy
        box = (label_x, label_y - height, label_x + width, label_y)
        if not _overlaps(box, occupied):
            occupied.append(box)
            return label_x, label_y
    label_x = x + 6
    label_y = y + 34 + (len(occupied) % 5) * (height + 2)
    occupied.append((label_x, label_y - height, label_x + width, label_y))
    return label_x, label_y


def _dimension_elements(tx: Any, ty: Any, dim: dict[str, Any]) -> list[str]:
    start = dim.get("start", {})
    end = dim.get("end", {})
    offset = dim.get("offset", {})
    label = escape(str(dim.get("label", "") or ""))

    sx = float(start.get("x", 0.0))
    sy = float(start.get("y", 0.0))
    ex = float(end.get("x", 0.0))
    ey = float(end.get("y", 0.0))
    ox = float(offset.get("x", 0.0))
    oy = float(offset.get("y", 0.0))

    x1 = tx(sx)
    y1 = ty(sy)
    x2 = tx(ex)
    y2 = ty(ey)
    dx1 = tx(sx + ox)
    dy1 = ty(sy + oy)
    dx2 = tx(ex + ox)
    dy2 = ty(ey + oy)
    mid_x = (dx1 + dx2) / 2
    mid_y = (dy1 + dy2) / 2

    return [
        f'<line x1="{x1:.2f}" y1="{y1:.2f}" x2="{dx1:.2f}" y2="{dy1:.2f}" stroke="black" stroke-width="1" stroke-dasharray="3 3"/>',
        f'<line x1="{x2:.2f}" y1="{y2:.2f}" x2="{dx2:.2f}" y2="{dy2:.2f}" stroke="black" stroke-width="1" stroke-dasharray="3 3"/>',
        f'<line x1="{dx1:.2f}" y1="{dy1:.2f}" x2="{dx2:.2f}" y2="{dy2:.2f}" stroke="black" stroke-width="1.2"/>',
        f'<text x="{mid_x + 4:.2f}" y="{mid_y - 4:.2f}" font-size="11" fill="black">{label}</text>',
    ]


def export_svg(
    pieces: PatternPiece | list[PatternPiece] | tuple[PatternPiece, ...] | list[Line] | tuple[Line, ...],
    output_path: str | Path,
) -> Path:
    normalized = _normalize_to_pieces(pieces)
    output = Path(output_path)
    output.parent.mkdir(parents=True, exist_ok=True)

    min_x, min_y, max_x, max_y = _canvas_bounds(normalized)
    width = max_x - min_x
    height = max_y - min_y
    scale = 10.0
    header_height = 90.0

    def tx(x: float) -> float:
        return (x - min_x) * scale

    def ty(y: float) -> float:
        return header_height + (y - min_y) * scale

    garment_code, garment_name, measurements = _garment_payload(normalized)
    measurement_text = " | ".join(format_measurements_for_header(measurements))
    piece_names = ", ".join(piece.name for piece in normalized)

    lines: list[str] = [
        '<?xml version="1.0" encoding="UTF-8"?>',
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width * scale:.2f}" height="{height * scale + header_height:.2f}" viewBox="0 0 {width * scale:.2f} {height * scale + header_height:.2f}">',
        '<rect width="100%" height="100%" fill="white"/>',
        '<text x="10" y="22" font-size="16" font-weight="bold" fill="black">Motor Patronaje 2D - Exportacion</text>',
    ]

    if garment_code or garment_name:
        lines.append(f'<text x="10" y="42" font-size="12" fill="black">Prenda: {escape((garment_code + " - " + garment_name).strip(" -"))}</text>')
    if measurement_text:
        lines.append(f'<text x="10" y="60" font-size="12" fill="black">Medidas: {escape(measurement_text)}</text>')
    if piece_names:
        lines.append(f'<text x="10" y="78" font-size="12" fill="black">Piezas: {escape(piece_names)}</text>')

    for piece in normalized:
        lines.append(f'<g id="{escape(piece.name)}">')
        for line in piece.lines:
            dash = _dash(line)
            stroke_width = "2" if line.kind == "pattern" else "1.5"
            lines.append(
                f'<line x1="{tx(float(line.start.x)):.2f}" y1="{ty(float(line.start.y)):.2f}" '
                f'x2="{tx(float(line.end.x)):.2f}" y2="{ty(float(line.end.y)):.2f}" '
                f'stroke="black" fill="none" stroke-width="{stroke_width}"{dash}/>'
            )

        piece_points = list(piece.points.values())
        if piece_points:
            piece_min_x = min(float(point.x) for point in piece_points)
            piece_min_y = min(float(point.y) for point in piece_points)
            lines.append(f'<text x="{tx(piece_min_x):.2f}" y="{ty(piece_min_y) - 12:.2f}" font-size="12" font-weight="bold" fill="black">{escape(piece.name)}</text>')

        for dim in (piece.metadata or {}).get("dimension_annotations", []):
            lines.extend(_dimension_elements(tx, ty, dim))

        names_to_show = displayable_point_names(piece.points)
        occupied: list[tuple[float, float, float, float]] = []
        for name in sorted(names_to_show, key=lambda item: (float(piece.points[item].y), float(piece.points[item].x), item)):
            point = piece.points[name]
            x = tx(float(point.x))
            y = ty(float(point.y))
            lines.append(f'<circle cx="{x:.2f}" cy="{y:.2f}" r="3" fill="black"/>')
            label_x, label_y = _label_position(x=x, y=y, text=name, font_size=11, occupied=occupied)
            lines.append(f'<text x="{label_x:.2f}" y="{label_y:.2f}" font-size="11" fill="black">{escape(name)}</text>')

        lines.append('</g>')

    lines.append('</svg>')
    output.write_text("\n".join(lines), encoding="utf-8")
    return output
PY

cat > tests/test_export_visual_metadata.py <<'PY'
from __future__ import annotations

from pathlib import Path

from engine.generation import PatternExportRequest, PatternGenerationRequest, export_generated_pattern


def _export_svg(tmp_path: Path, garment_code: str, measurements: dict[str, float], options: dict | None = None) -> str:
    result = export_generated_pattern(
        PatternExportRequest(
            generation_request=PatternGenerationRequest(
                garment_code=garment_code,
                measurements=measurements,
                options=options or {},
            ),
            output_name=f"{garment_code}_visual_metadata",
            output_dir=tmp_path,
            export_dxf=False,
            export_pdf=False,
        )
    )
    assert result.svg_path is not None
    return result.svg_path.read_text(encoding="utf-8")


def test_universal_export_svg_uses_spanish_header_measurements(tmp_path: Path) -> None:
    content = _export_svg(tmp_path, "falda_basica", {"waist": 72, "hip": 98, "skirt_length": 60}, {"full_pattern": True})

    assert "Cintura: 72 cm" in content
    assert "Cadera: 98 cm" in content
    assert "Largo falda: 60 cm" in content
    assert "waist:" not in content
    assert "skirt_length:" not in content


def test_pants_visual_export_hides_technical_generated_point_names(tmp_path: Path) -> None:
    content = _export_svg(
        tmp_path,
        "pantalon_basico",
        {"waist": 84, "hip": 104, "outseam": 100, "inseam": 76},
    )

    assert "line_1_start" not in content
    assert "line_5_end" not in content
    assert "Cintura pieza:" in content
    assert "Cadera pieza:" in content
    assert "Largo exterior pieza:" in content
PY

cat > tests/test_fase_40_1_cotas_visuales_universales.py <<'PY'
from __future__ import annotations

from pathlib import Path

from engine.generation import PatternExportRequest, PatternGenerationRequest, export_generated_pattern


def _svg_content(tmp_path: Path, garment_code: str, measurements: dict[str, float], options: dict | None = None) -> str:
    result = export_generated_pattern(
        PatternExportRequest(
            generation_request=PatternGenerationRequest(
                garment_code=garment_code,
                measurements=measurements,
                options=options or {},
            ),
            output_name=f"{garment_code}_fase_40_1",
            output_dir=tmp_path,
            export_dxf=False,
            export_pdf=False,
        )
    )
    assert result.svg_path is not None
    return result.svg_path.read_text(encoding="utf-8")


def test_falda_basica_has_real_piece_dimensions(tmp_path: Path) -> None:
    content = _svg_content(
        tmp_path,
        "falda_basica",
        {"waist": 73, "hip": 99, "skirt_length": 60, "ease": 2},
        {"full_pattern": True},
    )

    assert "Cintura: 73 cm" in content
    assert "Cintura pieza: 19.25 cm" in content
    assert "Cadera pieza: 25.75 cm" in content
    assert "Largo pieza: 60 cm" in content
    assert "Falda basica delantera" in content
    assert "Falda basica posterior" in content


def test_pantalon_basico_has_universal_dimensions_and_no_technical_points(tmp_path: Path) -> None:
    content = _svg_content(
        tmp_path,
        "pantalon_basico",
        {"waist": 84, "hip": 104, "outseam": 100, "inseam": 76},
    )

    assert "Cintura: 84 cm" in content
    assert "Cadera: 104 cm" in content
    assert "Largo exterior: 100 cm" in content
    assert "Entrepierna: 76 cm" in content
    assert "Cintura pieza:" in content
    assert "Cadera pieza:" in content
    assert "Largo exterior pieza: 100 cm" in content
    assert "line_1_start" not in content
    assert "line_1_end" not in content


def test_short_basico_has_universal_dimensions(tmp_path: Path) -> None:
    content = _svg_content(
        tmp_path,
        "short_basico",
        {"waist": 84, "hip": 104, "outseam": 45, "inseam": 20},
    )

    assert "Cintura: 84 cm" in content
    assert "Cadera: 104 cm" in content
    assert "Largo exterior: 45 cm" in content
    assert "Entrepierna: 20 cm" in content
    assert "Cintura pieza: 21 cm" in content
    assert "Cadera/pierna pieza: 26 cm" in content
    assert "Largo exterior pieza: 45 cm" in content


def test_falda_evase_has_universal_dimensions(tmp_path: Path) -> None:
    content = _svg_content(
        tmp_path,
        "falda_evase",
        {"waist": 73, "hip": 99, "skirt_length": 60, "ease": 12},
    )

    assert "Cintura: 73 cm" in content
    assert "Cadera: 99 cm" in content
    assert "Largo falda: 60 cm" in content
    assert "Cintura pieza: 18.25 cm" in content
    assert "Bajo pieza: 48.75 cm" in content
    assert "Largo falda: 60 cm" in content
PY

cat > docs/54_Fase_40_1_Cotas_Visuales_Universales.md <<'MD'
# Fase 40.1 - Cotas visuales universales por prenda

Fecha: 2026-07-05

## Objetivo

Convertir la salida visual PDF/SVG en una salida de producto para usuario final, no una salida tecnica interna.

## Problema detectado

Despues de corregir `falda_basica`, otras prendas seguian mostrando nombres tecnicos como:

```text
line_1_start
line_5_end
line_2_start
```

Ademas, las cotas no estaban colocadas al borde del patron para todas las prendas.

## Reglas de producto

1. El encabezado muestra medidas de entrada en espanol.
2. Las cotas al borde muestran medidas geometricas reales del segmento o proyeccion dibujada.
3. Los puntos tecnicos autogenerados no se muestran.
4. Solo se muestran nombres de puntos semanticos cuando existen.

## Prendas cubiertas

### falda_basica

- Cintura pieza.
- Cadera pieza.
- Largo pieza.

### pantalon_basico

- Cintura pieza.
- Cadera pieza.
- Largo exterior pieza.
- Entrepierna solo queda en encabezado porque la geometria MVP actual no dibuja un segmento interno explicito.

### short_basico

- Cintura pieza.
- Cadera/pierna pieza.
- Largo exterior pieza.
- Entrepierna queda en encabezado porque la geometria serializable actual no dibuja un segmento interno explicito.

### falda_evase

- Cintura pieza.
- Bajo pieza.
- Largo falda como proyeccion vertical de la geometria.

## Archivos principales

```text
engine/exports/visual_annotations.py
engine/generation/exporter.py
engine/exports/pdf/writer.py
engine/exports/svg/writer.py
tests/test_export_visual_metadata.py
tests/test_fase_40_1_cotas_visuales_universales.py
```

## Validacion

```bash
make validate-fase-40
```

Resultado esperado:

```text
VALIDATE_FASE_40_1_OK
```
MD

python3 - <<'PY'
from pathlib import Path

makefile = Path("Makefile")
text = makefile.read_text(encoding="utf-8")

validate_block = '''validate-fase-40:\n\t.venv/bin/python -m pytest tests/test_gui_universal_controller.py tests/test_export_visual_metadata.py tests/test_fase_40_export_visual_layout.py tests/test_fase_40_1_cotas_visuales_universales.py -q\n\t.venv/bin/python scripts/list_garments.py\n\t.venv/bin/python scripts/generate_pattern.py --garment short_basico --waist 84 --hip 104 --outseam 45 --inseam 20\n\t.venv/bin/python scripts/generate_pattern.py --garment falda_evase --waist 73 --hip 99 --skirt-length 60 --ease 12\n\t.venv/bin/python scripts/generate_pattern.py --garment falda_basica --waist 73 --hip 99 --skirt-length 60 --ease 2\n\t@echo VALIDATE_FASE_40_1_OK\n'''

if "validate-fase-40:" in text:
    start = text.index("validate-fase-40:")
    end = text.find("\n\n", start)
    if end == -1:
        end = len(text)
    text = text[:start] + validate_block + text[end:]
else:
    if not text.endswith("\n"):
        text += "\n"
    text += "\n" + validate_block

lines = text.splitlines()
for idx, line in enumerate(lines):
    if line.startswith(".PHONY:") and "validate-fase-40" not in line:
        lines[idx] = line + " validate-fase-40"
        break
text = "\n".join(lines) + "\n"
makefile.write_text(text, encoding="utf-8")
PY

echo "== Validacion puntual de Fase 40.1 =="
.venv/bin/python - <<'PY'
from engine.generation import PatternExportRequest, PatternGenerationRequest, export_generated_pattern
from pathlib import Path
import tempfile

with tempfile.TemporaryDirectory() as tmp:
    result = export_generated_pattern(
        PatternExportRequest(
            generation_request=PatternGenerationRequest(
                garment_code="pantalon_basico",
                measurements={"waist": 84, "hip": 104, "outseam": 100, "inseam": 76},
            ),
            output_name="pantalon_fase_40_1_check",
            output_dir=Path(tmp),
            export_dxf=False,
            export_pdf=False,
        )
    )
    assert result.svg_path is not None
    content = result.svg_path.read_text(encoding="utf-8")
    assert "line_1_start" not in content
    assert "Cintura pieza:" in content
    assert "Cadera pieza:" in content
    assert "Largo exterior pieza:" in content
print("COTAS_VISUALES_UNIVERSALES_OK")
PY

echo "== Validaciones Fase 40.1 =="
make validate-fase-40

echo "== Limpieza de exports generados por validacion =="
rm -rf exports

echo "== Estado Git despues de Fase 40.1 =="
git status --short

echo "== Fase 40.1 aplicada correctamente =="
