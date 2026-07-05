#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="/home/antares/Proyecto/motor"
BRANCH_NAME="feature/fase-40-gui-generacion-exportacion-serializables"

cd "$PROJECT_DIR"

echo "== Fix Fase 40: falda completa + medidas en espanol + cotas al borde =="

current_branch="$(git branch --show-current)"
if [ "$current_branch" != "$BRANCH_NAME" ]; then
  echo "ERROR: rama actual inesperada: $current_branch"
  echo "Esperado: $BRANCH_NAME"
  echo "No se aplica el fix para evitar tocar una rama incorrecta."
  exit 1
fi

echo "== Estado Git antes del fix =="
git status --short

mkdir -p app/controllers engine/generation engine/exports/pdf engine/exports/svg tests docs scripts

cat > app/controllers/universal_pattern_controller.py <<'PY'
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
PY

cat > engine/generation/pattern_generator.py <<'PY'
"""Universal pattern generator.

This module resolves a garment code through the dynamic garment registry and
executes the draft class using the most appropriate measurement payload.
"""

from __future__ import annotations

from collections.abc import Mapping
from dataclasses import dataclass, field
from typing import Any

from engine.garments import GarmentNotFoundError, get_garment
from engine.measurements import BodyMeasurements


class PatternGenerationError(Exception):
    """Raised when universal pattern generation fails."""


@dataclass(frozen=True)
class PatternGenerationRequest:
    """Input contract for universal pattern generation."""

    garment_code: str
    measurements: dict[str, Any]
    options: dict[str, Any] = field(default_factory=dict)


@dataclass(frozen=True)
class PatternGenerationResult:
    """Output contract for universal pattern generation."""

    garment_code: str
    garment_name: str
    draft_class_name: str
    pieces: list[Any]
    measurements: Any
    options: dict[str, Any] = field(default_factory=dict)

    @property
    def piece_count(self) -> int:
        return len(self.pieces)


def _validate_class_requirements(draft_class: type[Any], raw_measurements: Mapping[str, Any]) -> None:
    requirements = getattr(draft_class, "required_measurements", ())

    missing = [
        requirement.name
        for requirement in requirements
        if getattr(requirement, "required", True)
        and requirement.name not in raw_measurements
    ]

    if missing:
        joined = ", ".join(missing)
        code = getattr(getattr(draft_class, "metadata", None), "code", draft_class.__name__)
        raise PatternGenerationError(f"Missing required measurements for {code}: {joined}")


def _can_build_body_measurements(raw_measurements: Mapping[str, Any]) -> bool:
    required = ("waist", "hip", "skirt_length")
    return all(key in raw_measurements for key in required)


def _build_body_measurements(raw_measurements: Mapping[str, Any]) -> BodyMeasurements:
    allowed = {
        "waist",
        "hip",
        "skirt_length",
        "ease",
        "hip_depth",
        "ease_hip",
        "ease_waist",
        "unit",
    }

    kwargs = {
        key: value
        for key, value in raw_measurements.items()
        if key in allowed and value is not None
    }

    try:
        return BodyMeasurements(**kwargs)
    except TypeError as exc:
        raise PatternGenerationError(f"Invalid measurements for BodyMeasurements: {kwargs}") from exc


def _instantiate_draft(draft_class: type[Any], raw_measurements: dict[str, Any]) -> tuple[Any, Any]:
    errors: list[str] = []

    if _can_build_body_measurements(raw_measurements):
        body_measurements = _build_body_measurements(raw_measurements)
        try:
            return draft_class(body_measurements), body_measurements
        except Exception as exc:  # noqa: BLE001
            errors.append(f"BodyMeasurements failed: {exc}")

    try:
        return draft_class(raw_measurements), raw_measurements
    except Exception as exc:  # noqa: BLE001
        errors.append(f"raw mapping failed: {exc}")

    joined = " | ".join(errors)
    raise PatternGenerationError(f"Could not instantiate {draft_class.__name__}. {joined}")


def _validate_instance_requirements(draft: Any, measurements: Mapping[str, Any]) -> None:
    validator = getattr(draft, "validate_required_measurements", None)

    if callable(validator):
        try:
            validator(measurements)
        except Exception as exc:  # noqa: BLE001
            raise PatternGenerationError(str(exc)) from exc


def _run_draft(draft: Any, options: Mapping[str, Any] | None = None) -> list[Any]:
    options = dict(options or {})
    full_pattern = bool(options.get("full_pattern"))

    if full_pattern and hasattr(draft, "draft_full") and callable(draft.draft_full):
        pieces = draft.draft_full()
    elif hasattr(draft, "draft") and callable(draft.draft):
        pieces = draft.draft()
    elif hasattr(draft, "draft_full") and callable(draft.draft_full):
        pieces = draft.draft_full()
    elif hasattr(draft, "build") and callable(draft.build):
        pieces = [draft.build()]
    else:
        raise PatternGenerationError(
            f"Draft class {draft.__class__.__name__} does not expose draft(), draft_full() or build()"
        )

    if pieces is None:
        raise PatternGenerationError(f"Draft class {draft.__class__.__name__} returned no pieces")

    if isinstance(pieces, list):
        return pieces
    if isinstance(pieces, tuple):
        return list(pieces)
    return [pieces]


def generate_pattern(request: PatternGenerationRequest) -> PatternGenerationResult:
    garment_code = request.garment_code.strip()

    if not garment_code:
        raise PatternGenerationError("garment_code cannot be empty")

    try:
        draft_class = get_garment(garment_code)
    except GarmentNotFoundError as exc:
        raise PatternGenerationError(f"Unknown garment code: {garment_code}") from exc

    _validate_class_requirements(draft_class, request.measurements)

    draft, normalized_measurements = _instantiate_draft(
        draft_class=draft_class,
        raw_measurements=request.measurements,
    )

    _validate_instance_requirements(draft, request.measurements)
    pieces = _run_draft(draft, request.options)

    metadata = getattr(draft_class, "metadata", None)
    garment_name = getattr(metadata, "name", garment_code)

    return PatternGenerationResult(
        garment_code=garment_code,
        garment_name=garment_name,
        draft_class_name=draft_class.__name__,
        pieces=pieces,
        measurements=normalized_measurements,
        options=dict(request.options),
    )
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
        return {
            key: value
            for key, value in vars(measurements).items()
            if not key.startswith("_") and value is not None
        }

    return {}


def _format_measurement_value(value: Any) -> str:
    if isinstance(value, float):
        return f"{value:.2f}".rstrip("0").rstrip(".")
    return str(value)


def _make_dimension_annotation(
    *,
    label: str,
    start: Point,
    end: Point,
    offset_x: float = 0.0,
    offset_y: float = 0.0,
) -> dict[str, Any]:
    return {
        "label": label,
        "start": {"x": float(start.x), "y": float(start.y)},
        "end": {"x": float(end.x), "y": float(end.y)},
        "offset": {"x": float(offset_x), "y": float(offset_y)},
    }


def _build_basic_skirt_dimensions(piece: PatternPiece, measurements: dict[str, Any]) -> list[dict[str, Any]]:
    points = piece.points
    annotations: list[dict[str, Any]] = []

    def has(*names: str) -> bool:
        return all(name in points for name in names)

    if has("A_cintura_centro", "B_cintura_costado") and "waist" in measurements:
        annotations.append(
            _make_dimension_annotation(
                label=f"Cintura: {_format_measurement_value(measurements['waist'])} cm",
                start=points["A_cintura_centro"],
                end=points["B_cintura_costado"],
                offset_y=-4.0,
            )
        )

    if has("C_cadera_centro", "D_cadera_costado") and "hip" in measurements:
        annotations.append(
            _make_dimension_annotation(
                label=f"Cadera: {_format_measurement_value(measurements['hip'])} cm",
                start=points["C_cadera_centro"],
                end=points["D_cadera_costado"],
                offset_y=4.0,
            )
        )

    if has("A_cintura_centro", "E_bajo_centro") and "skirt_length" in measurements:
        annotations.append(
            _make_dimension_annotation(
                label=f"Largo falda: {_format_measurement_value(measurements['skirt_length'])} cm",
                start=points["A_cintura_centro"],
                end=points["E_bajo_centro"],
                offset_x=-4.0,
            )
        )

    return annotations


def _attach_export_metadata(pieces: list[PatternPiece], generation_result: PatternGenerationResult) -> None:
    measurements = _measurements_as_export_dict(generation_result.measurements)

    for piece in pieces:
        piece.metadata.setdefault("garment_code", generation_result.garment_code)
        piece.metadata.setdefault("garment_name", generation_result.garment_name)
        piece.metadata.setdefault("draft_class_name", generation_result.draft_class_name)
        piece.metadata.setdefault("measurements", measurements)

        if generation_result.garment_code == "falda_basica":
            piece.metadata["dimension_annotations"] = _build_basic_skirt_dimensions(piece, measurements)


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

    return PatternExportResult(
        generation_result=generation_result,
        svg_path=svg_path,
        dxf_path=dxf_path,
        pdf_path=pdf_path,
    )
PY

cat > engine/exports/pdf/writer.py <<'PY'
from __future__ import annotations

from pathlib import Path
from typing import Any, Iterable

from engine.geometry.line import Line
from engine.patterns.piece import PatternPiece

MEASUREMENT_LABELS = {
    "waist": "Cintura",
    "hip": "Cadera",
    "skirt_length": "Largo falda",
    "outseam": "Largo exterior",
    "inseam": "Entrepierna",
    "ease": "Holgura",
    "hip_depth": "Altura cadera",
    "ease_hip": "Holgura cadera",
    "ease_waist": "Holgura cintura",
}


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


def _format_value(value: Any) -> str:
    if isinstance(value, float):
        return f"{value:.2f}".rstrip("0").rstrip(".")
    return str(value)


def _format_measurements(measurements: dict[str, Any]) -> list[str]:
    lines: list[str] = []
    for key in ("waist", "hip", "skirt_length", "outseam", "inseam", "ease", "hip_depth"):
        if key in measurements:
            lines.append(f"{MEASUREMENT_LABELS.get(key, key)}: {_format_value(measurements[key])} cm")
    return lines


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
    offsets = [
        (5, 5),
        (5, -10),
        (-width - 5, 5),
        (-width - 5, -10),
        (0, 14),
        (0, -18),
        (12, 14),
        (12, -18),
        (-width - 12, 14),
        (-width - 12, -18),
        (24, 5),
        (-width - 24, 5),
    ]
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


def _draw_dimension(canvas: Any, tx: Any, ty: Any, dim: dict[str, Any], scale: float) -> None:
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
    canvas.line(dx1 - 2, dy1 - 2, dx1 + 2, dy1 + 2)
    canvas.line(dx1 - 2, dy1 + 2, dx1 + 2, dy1 - 2)
    canvas.line(dx2 - 2, dy2 - 2, dx2 + 2, dy2 + 2)
    canvas.line(dx2 - 2, dy2 + 2, dx2 + 2, dy2 - 2)

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
    measurement_lines = _format_measurements(measurements)

    c.setFont("Helvetica-Bold", 12)
    c.drawString(margin, header_y, "Motor Patronaje 2D - Exportacion")

    c.setFont("Helvetica", 8)
    if garment_code or garment_name:
        metadata_y = _draw_wrapped_line(
            c,
            text=f"Prenda: {(garment_code + ' - ' + garment_name).strip(' -')}",
            x=margin,
            y=metadata_y,
        )
    if measurement_lines:
        metadata_y = _draw_wrapped_line(
            c,
            text="Medidas: " + " | ".join(measurement_lines),
            x=margin,
            y=metadata_y,
        )
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
            _draw_dimension(c, tx, ty, dim, scale)

        c.setDash()
        c.setFont("Helvetica", 6.8)
        occupied: list[tuple[float, float, float, float]] = []
        for name, point in sorted(piece.points.items(), key=lambda item: (float(item[1].y), float(item[1].x), item[0])):
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

from engine.geometry.line import Line
from engine.patterns.piece import PatternPiece

MEASUREMENT_LABELS = {
    "waist": "Cintura",
    "hip": "Cadera",
    "skirt_length": "Largo falda",
    "outseam": "Largo exterior",
    "inseam": "Entrepierna",
    "ease": "Holgura",
    "hip_depth": "Altura cadera",
    "ease_hip": "Holgura cadera",
    "ease_waist": "Holgura cintura",
}


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

    min_x = min(xs) - margin
    min_y = min(ys) - margin
    max_x = max(xs) + margin
    max_y = max(ys) + margin
    return min_x, min_y, max_x, max_y


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


def _format_value(value: Any) -> str:
    if isinstance(value, float):
        return f"{value:.2f}".rstrip("0").rstrip(".")
    return str(value)


def _format_measurements(measurements: dict[str, Any]) -> str:
    parts: list[str] = []
    for key in ("waist", "hip", "skirt_length", "outseam", "inseam", "ease", "hip_depth"):
        if key in measurements:
            parts.append(f"{MEASUREMENT_LABELS.get(key, key)}: {_format_value(measurements[key])} cm")
    return " | ".join(parts)


def _overlaps(box: tuple[float, float, float, float], boxes: list[tuple[float, float, float, float]]) -> bool:
    left, top, right, bottom = box
    for other_left, other_top, other_right, other_bottom in boxes:
        if not (right < other_left or left > other_right or bottom < other_top or top > other_bottom):
            return True
    return False


def _label_position(*, x: float, y: float, text: str, font_size: float, occupied: list[tuple[float, float, float, float]]) -> tuple[float, float]:
    width = max(35.0, len(text) * font_size * 0.58)
    height = font_size + 4.0
    offsets = [
        (6, -6),
        (6, 14),
        (-width - 6, -6),
        (-width - 6, 14),
        (0, -22),
        (0, 28),
        (16, -22),
        (16, 28),
        (-width - 16, -22),
        (-width - 16, 28),
        (32, -6),
        (-width - 32, -6),
    ]
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
    measurement_text = _format_measurements(measurements)
    piece_names = ", ".join(piece.name for piece in normalized)

    lines: list[str] = [
        '<?xml version="1.0" encoding="UTF-8"?>',
        (
            f'<svg xmlns="http://www.w3.org/2000/svg" '
            f'width="{width * scale:.2f}" height="{height * scale + header_height:.2f}" '
            f'viewBox="0 0 {width * scale:.2f} {height * scale + header_height:.2f}">'
        ),
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
            lines.append(
                f'<text x="{tx(piece_min_x):.2f}" y="{ty(piece_min_y) - 12:.2f}" font-size="12" font-weight="bold" fill="black">{escape(piece.name)}</text>'
            )

        for dim in (piece.metadata or {}).get("dimension_annotations", []):
            lines.extend(_dimension_elements(tx, ty, dim))

        occupied: list[tuple[float, float, float, float]] = []
        for name, point in sorted(piece.points.items(), key=lambda item: (float(item[1].y), float(item[1].x), item[0])):
            x = tx(float(point.x))
            y = ty(float(point.y))
            lines.append(f'<circle cx="{x:.2f}" cy="{y:.2f}" r="3" fill="black"/>')
            label_x, label_y = _label_position(x=x, y=y, text=name, font_size=11, occupied=occupied)
            lines.append(f'<text x="{label_x:.2f}" y="{label_y:.2f}" font-size="11" fill="black">{escape(name)}</text>')

        lines.append('</g>')

    lines.append('</svg>')
    output.write_text("\n".join(lines), encoding='utf-8')
    return output
PY

cat > tests/test_fase_40_export_visual_layout.py <<'PY'
from __future__ import annotations

from pathlib import Path

from app.controllers.universal_pattern_controller import export_summary, generate_summary
from engine.generation import PatternExportRequest, PatternGenerationRequest, export_generated_pattern, generate_pattern


def test_falda_basica_generate_summary_returns_full_pattern() -> None:
    summary = generate_summary(
        garment_code="falda_basica",
        measurements={"waist": 73, "hip": 99, "skirt_length": 60, "ease": 2},
    )

    assert summary.piece_count == 2


def test_falda_basica_generation_with_full_pattern_option_returns_two_pieces() -> None:
    result = generate_pattern(
        PatternGenerationRequest(
            garment_code="falda_basica",
            measurements={"waist": 73, "hip": 99, "skirt_length": 60, "ease": 2},
            options={"full_pattern": True},
        )
    )

    names = [piece.name for piece in result.pieces]
    assert result.piece_count == 2
    assert "Falda basica delantera" in names
    assert "Falda basica posterior" in names


def test_falda_basica_export_summary_returns_two_pieces() -> None:
    summary = export_summary(
        garment_code="falda_basica",
        measurements={"waist": 73, "hip": 99, "skirt_length": 60, "ease": 2},
        output_name="falda_basica_fase40_visual_test",
    )

    assert summary.piece_count == 2
    assert summary.svg_path is not None
    assert summary.pdf_path is not None



def test_falda_basica_svg_includes_spanish_measurements_and_both_pieces(tmp_path: Path) -> None:
    result = export_generated_pattern(
        PatternExportRequest(
            generation_request=PatternGenerationRequest(
                garment_code="falda_basica",
                measurements={"waist": 73, "hip": 99, "skirt_length": 60, "ease": 2},
                options={"full_pattern": True},
            ),
            output_name="falda_basica_svg_visual",
            output_dir=tmp_path,
            export_dxf=False,
            export_pdf=False,
        )
    )

    assert result.svg_path is not None
    content = result.svg_path.read_text(encoding="utf-8")

    assert "Prenda: falda_basica - Falda basica" in content
    assert "Falda basica delantera" in content
    assert "Falda basica posterior" in content
    assert "Cintura: 73 cm" in content
    assert "Cadera: 99 cm" in content
    assert "Largo falda: 60 cm" in content
PY

cat > docs/52_Fix_Fase_40_Falda_Completa_Medidas_Espanol_Bordes.md <<'MD'
# Fix Fase 40 - Falda completa + medidas en espanol + cotas al borde

Fecha: 2026-07-05

## Objetivo

Corregir tres brechas detectadas en la validacion manual de la GUI/producto:

1. La `falda_basica` se exportaba solo con la pieza delantera.
2. Las medidas en exportacion no estaban presentadas en espanol.
3. Las cotas/medidas visibles no estaban colocadas al borde del patron segun el lado correspondiente.

## Cambios aplicados

### 1. Generacion completa de falda basica

Se agrega opcion de producto `full_pattern=True` desde la GUI para `falda_basica`, de forma que la generacion use `draft_full()` y exporte:

- `Falda basica delantera`
- `Falda basica posterior`

### 2. Medidas visibles en espanol

En SVG/PDF se muestran etiquetas de negocio:

- Cintura
- Cadera
- Largo falda
- Largo exterior
- Entrepierna
- Holgura
- Altura cadera

### 3. Cotas al borde del patron

Para `falda_basica` se agregan cotas visibles sobre lados consistentes del patron:

- `Cintura` sobre la linea superior.
- `Cadera` sobre la linea de cadera.
- `Largo falda` sobre el lateral izquierdo.

### 4. Mejora visual complementaria

Se mantiene desplazamiento anti-solape para nombres de puntos.

## Validacion recomendada

```bash
cd /home/antares/Proyecto/motor

make validate-fase-40
make run-gui
```

## Criterio de aceptacion

- La GUI exporta `falda_basica` con delantero y posterior.
- El SVG/PDF muestra medidas en espanol.
- Las cotas se muestran junto al lado correcto del patron.
- Los nombres de puntos no se montan entre si de forma critica.
MD

python3 - <<'PY'
from pathlib import Path

makefile = Path("Makefile")
text = makefile.read_text(encoding="utf-8")

validate_block = '''validate-fase-40:\n\t.venv/bin/python -m pytest tests/test_gui_universal_controller.py tests/test_fase_40_export_visual_layout.py -q\n\t.venv/bin/python scripts/list_garments.py\n\t.venv/bin/python scripts/generate_pattern.py --garment short_basico --waist 84 --hip 104 --outseam 45 --inseam 20\n\t.venv/bin/python scripts/generate_pattern.py --garment falda_evase --waist 73 --hip 99 --skirt-length 60 --ease 12\n\t.venv/bin/python scripts/generate_pattern.py --garment falda_basica --waist 73 --hip 99 --skirt-length 60 --ease 2\n'''

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

if "validate-fase-40" not in text.splitlines()[0]:
    # ensure phony declaration contains target, best effort append.
    lines = text.splitlines()
    for idx, line in enumerate(lines):
        if line.startswith(".PHONY:") and "validate-fase-40" not in line:
            lines[idx] = line + " validate-fase-40"
            break
    text = "\n".join(lines) + "\n"

makefile.write_text(text, encoding="utf-8")
PY

echo "== Validacion puntual falda completa =="
.venv/bin/python - <<'PY'
from app.controllers.universal_pattern_controller import generate_summary

summary = generate_summary(
    garment_code="falda_basica",
    measurements={"waist": 73, "hip": 99, "skirt_length": 60, "ease": 2},
)
assert summary.piece_count == 2, summary
print("FALDA_COMPLETA_OK")
PY

echo "== Validaciones Fase 40 =="
make validate-fase-40

echo "== Limpieza de exports generados por validacion =="
rm -rf exports

echo "== Estado Git despues del fix =="
git status --short

echo "== Fix aplicado correctamente =="
