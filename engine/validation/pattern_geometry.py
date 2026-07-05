"""Geometry quality checks for generated pattern pieces and exported files."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable


class PatternGeometryValidationError(ValueError):
    """Raised when generated pattern geometry is structurally invalid."""


@dataclass(frozen=True)
class BoundingBox:
    """Axis-aligned bounding box in pattern units."""

    min_x: float
    min_y: float
    max_x: float
    max_y: float

    @property
    def width(self) -> float:
        return self.max_x - self.min_x

    @property
    def height(self) -> float:
        return self.max_y - self.min_y

    @property
    def area(self) -> float:
        return self.width * self.height


@dataclass(frozen=True)
class PieceGeometryReport:
    """Computed geometry report for one generated piece."""

    name: str
    line_count: int
    point_count: int
    bounding_box: BoundingBox

    @property
    def width(self) -> float:
        return self.bounding_box.width

    @property
    def height(self) -> float:
        return self.bounding_box.height

    @property
    def min_x(self) -> float:
        return self.bounding_box.min_x

    @property
    def min_y(self) -> float:
        return self.bounding_box.min_y

    @property
    def max_x(self) -> float:
        return self.bounding_box.max_x

    @property
    def max_y(self) -> float:
        return self.bounding_box.max_y

    @property
    def area(self) -> float:
        return self.bounding_box.area


@dataclass(frozen=True)
class PatternGeometryReport:
    """Computed geometry report for a full generated pattern."""

    garment_code: str
    piece_reports: tuple[PieceGeometryReport, ...]

    @property
    def piece_count(self) -> int:
        return len(self.piece_reports)


def _point_xy(point: Any) -> tuple[float, float]:
    if hasattr(point, "x") and hasattr(point, "y"):
        return (float(point.x), float(point.y))

    if isinstance(point, (tuple, list)) and len(point) >= 2:
        return (float(point[0]), float(point[1]))

    if isinstance(point, dict):
        if "x" in point and "y" in point:
            return (float(point["x"]), float(point["y"]))
        if 0 in point and 1 in point:
            return (float(point[0]), float(point[1]))

    raise PatternGeometryValidationError(f"Invalid point object: {point!r}")


def _line_endpoints(piece: Any, line: Any) -> tuple[tuple[float, float], tuple[float, float]]:
    if hasattr(line, "start") and hasattr(line, "end"):
        return (_point_xy(line.start), _point_xy(line.end))

    if isinstance(line, (tuple, list)) and len(line) == 2:
        start_key, end_key = line
    elif isinstance(line, dict) and "start" in line and "end" in line:
        start_key, end_key = line["start"], line["end"]
    else:
        raise PatternGeometryValidationError(f"Invalid line object: {line!r}")

    points = getattr(piece, "points", None)
    if not isinstance(points, dict):
        raise PatternGeometryValidationError(
            f"Line reference requires piece.points dict: {line!r}"
        )

    try:
        start = points[start_key]
        end = points[end_key]
    except KeyError as exc:
        raise PatternGeometryValidationError(
            f"Line references unknown point {exc.args[0]!r}: {line!r}"
        ) from exc

    return (_point_xy(start), _point_xy(end))


def _collect_piece_points(piece: Any) -> list[tuple[float, float]]:
    if not hasattr(piece, "lines"):
        raise PatternGeometryValidationError(f"Piece without lines: {piece!r}")

    coordinates: list[tuple[float, float]] = []
    for line in piece.lines:
        start, end = _line_endpoints(piece, line)
        coordinates.extend([start, end])

    return coordinates


def compute_piece_geometry_report(piece: Any) -> PieceGeometryReport:
    """Return geometry report for one generated piece."""

    name = getattr(piece, "name", "")
    if not name:
        raise PatternGeometryValidationError(f"Piece without name: {piece!r}")

    coordinates = _collect_piece_points(piece)
    if not coordinates:
        raise PatternGeometryValidationError(f"Piece without drawable coordinates: {piece!r}")

    xs = [point[0] for point in coordinates]
    ys = [point[1] for point in coordinates]
    bbox = BoundingBox(min(xs), min(ys), max(xs), max(ys))

    if bbox.width <= 0:
        raise PatternGeometryValidationError(
            f"Piece {name!r} has non-positive width: {bbox.width}"
        )
    if bbox.height <= 0:
        raise PatternGeometryValidationError(
            f"Piece {name!r} has non-positive height: {bbox.height}"
        )
    if bbox.area <= 0:
        raise PatternGeometryValidationError(
            f"Piece {name!r} has non-positive area: {bbox.area}"
        )

    unique_points = set(coordinates)
    return PieceGeometryReport(
        name=name,
        line_count=len(piece.lines),
        point_count=len(unique_points),
        bounding_box=bbox,
    )


def compute_pattern_geometry_report(
    *, garment_code: str, pieces: Iterable[Any]
) -> PatternGeometryReport:
    """Return geometry report for all generated pieces."""

    reports = tuple(compute_piece_geometry_report(piece) for piece in pieces)
    if not reports:
        raise PatternGeometryValidationError(
            f"Garment {garment_code!r} generated no pieces"
        )

    return PatternGeometryReport(garment_code=garment_code, piece_reports=reports)


def validate_exported_files(paths: Iterable[Path], *, min_bytes: int = 100) -> tuple[Path, ...]:
    """Validate that exported files exist and are not empty/trivial."""

    validated: list[Path] = []
    for path in paths:
        if not path.exists():
            raise PatternGeometryValidationError(f"Exported file does not exist: {path}")
        if not path.is_file():
            raise PatternGeometryValidationError(f"Exported path is not a file: {path}")
        size = path.stat().st_size
        if size < min_bytes:
            raise PatternGeometryValidationError(
                f"Exported file is too small: {path} ({size} bytes)"
            )
        validated.append(path)

    return tuple(validated)
