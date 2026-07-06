"""Apply editable transformations over pattern-piece copies."""

from __future__ import annotations

import copy
from types import SimpleNamespace
from typing import Any, Iterable

from engine.geometry.point import Point
from engine.transformations.operations import PatternVariant, TransformOperation


class TransformError(ValueError):
    """Raised when an editable transformation cannot be applied safely."""


def _line_label(line: Any) -> str:
    return str(getattr(line, "label", getattr(line, "name", "")) or "")


def _line_kind(line: Any) -> str:
    return str(getattr(line, "kind", "pattern") or "pattern")


def _make_line_like(line: Any, start: Point, end: Point) -> Any:
    label = _line_label(line)
    kind = _line_kind(line)
    if hasattr(line, "__dataclass_fields__"):
        try:
            fields = set(line.__dataclass_fields__.keys())
            kwargs: dict[str, Any] = {"start": start, "end": end}
            if "label" in fields:
                kwargs["label"] = label
            if "name" in fields:
                kwargs["name"] = label
            if "kind" in fields:
                kwargs["kind"] = kind
            return line.__class__(**kwargs)
        except Exception:  # noqa: BLE001 - fallback preserves execution
            pass
    return SimpleNamespace(start=start, end=end, label=label, name=label, kind=kind)


def _find_piece(pieces: list[Any], piece_name: str) -> Any:
    for piece in pieces:
        if getattr(piece, "name", "") == piece_name:
            return piece
    raise TransformError(f"Piece '{piece_name}' not found")


def _point_matches(point: Point, other: Point) -> bool:
    return abs(float(point.x) - float(other.x)) < 1e-9 and abs(float(point.y) - float(other.y)) < 1e-9


def _sync_lines_after_points(piece: Any, old_points: dict[str, Point]) -> None:
    updated_lines = []
    for line in list(getattr(piece, "lines", []) or []):
        start = line.start
        end = line.end
        for point_name, old_point in old_points.items():
            new_point = piece.points.get(point_name)
            if new_point is None:
                continue
            if _point_matches(start, old_point):
                start = new_point
            if _point_matches(end, old_point):
                end = new_point
        updated_lines.append(_make_line_like(line, start, end))
    piece.lines = updated_lines


def _move_named_point(piece: Any, point_name: str, dx: float, dy: float) -> None:
    if point_name not in piece.points:
        raise TransformError(f"Point '{point_name}' not found in piece '{piece.name}'")
    old_points = {point_name: piece.points[point_name]}
    piece.points[point_name] = piece.points[point_name].translate(dx=float(dx), dy=float(dy))
    _sync_lines_after_points(piece, old_points)


def _move_line_by_points(piece: Any, start_point: str, end_point: str, dx: float, dy: float) -> None:
    for name in (start_point, end_point):
        if name not in piece.points:
            raise TransformError(f"Point '{name}' not found in piece '{piece.name}'")
    old_points = {start_point: piece.points[start_point], end_point: piece.points[end_point]}
    piece.points[start_point] = piece.points[start_point].translate(dx=float(dx), dy=float(dy))
    piece.points[end_point] = piece.points[end_point].translate(dx=float(dx), dy=float(dy))
    _sync_lines_after_points(piece, old_points)


def _move_line_by_label(piece: Any, line_name: str, dx: float, dy: float) -> None:
    found = False
    updated_lines = []
    for line in list(getattr(piece, "lines", []) or []):
        if _line_label(line) == line_name:
            found = True
            updated_lines.append(_make_line_like(line, line.start.translate(dx=dx, dy=dy), line.end.translate(dx=dx, dy=dy)))
        else:
            updated_lines.append(line)
    if not found:
        raise TransformError(f"Line '{line_name}' not found in piece '{piece.name}'")
    piece.lines = updated_lines


def _scale_line_by_points(piece: Any, start_point: str, end_point: str, factor: float, anchor: str) -> None:
    if factor <= 0:
        raise TransformError("scale_line factor must be greater than zero")
    for name in (start_point, end_point):
        if name not in piece.points:
            raise TransformError(f"Point '{name}' not found in piece '{piece.name}'")

    start = piece.points[start_point]
    end = piece.points[end_point]
    sx, sy = float(start.x), float(start.y)
    ex, ey = float(end.x), float(end.y)

    if anchor == "start":
        new_start = start
        new_end = Point(sx + (ex - sx) * factor, sy + (ey - sy) * factor)
    elif anchor == "end":
        new_end = end
        new_start = Point(ex + (sx - ex) * factor, ey + (sy - ey) * factor)
    elif anchor == "center":
        cx, cy = (sx + ex) / 2.0, (sy + ey) / 2.0
        new_start = Point(cx + (sx - cx) * factor, cy + (sy - cy) * factor)
        new_end = Point(cx + (ex - cx) * factor, cy + (ey - cy) * factor)
    else:
        raise TransformError(f"Unsupported scale_line anchor: {anchor}")

    old_points = {start_point: start, end_point: end}
    piece.points[start_point] = new_start
    piece.points[end_point] = new_end
    _sync_lines_after_points(piece, old_points)


def _scale_line_by_label(piece: Any, line_name: str, factor: float) -> None:
    if factor <= 0:
        raise TransformError("scale_line factor must be greater than zero")
    found = False
    updated_lines = []
    for line in list(getattr(piece, "lines", []) or []):
        if _line_label(line) == line_name:
            found = True
            sx, sy = float(line.start.x), float(line.start.y)
            ex = sx + (float(line.end.x) - sx) * factor
            ey = sy + (float(line.end.y) - sy) * factor
            updated_lines.append(_make_line_like(line, line.start, Point(ex, ey)))
        else:
            updated_lines.append(line)
    if not found:
        raise TransformError(f"Line '{line_name}' not found in piece '{piece.name}'")
    piece.lines = updated_lines


def _curve_matches(curve: dict[str, Any], curve_name: str) -> bool:
    values = [curve.get("name"), curve.get("label"), curve.get("intent"), curve.get("id")]
    return any(str(value) == curve_name for value in values if value is not None)


def _move_control_dict(point: dict[str, Any], dx: float, dy: float) -> dict[str, float]:
    return {"x": float(point.get("x", 0.0)) + float(dx), "y": float(point.get("y", 0.0)) + float(dy)}


def _adjust_curve(piece: Any, curve_name: str, control_delta: dict[str, float], operation: TransformOperation) -> None:
    structural = list(getattr(piece, "metadata", {}).get("structural_curves", []) or [])
    updated = False

    for curve in structural:
        if not isinstance(curve, dict) or not _curve_matches(curve, curve_name):
            continue
        if "control1" in curve and isinstance(curve["control1"], dict):
            curve["control1"] = _move_control_dict(
                curve["control1"],
                float(control_delta.get("c1_dx", control_delta.get("control1_dx", 0.0))),
                float(control_delta.get("c1_dy", control_delta.get("control1_dy", 0.0))),
            )
        if "control2" in curve and isinstance(curve["control2"], dict):
            curve["control2"] = _move_control_dict(
                curve["control2"],
                float(control_delta.get("c2_dx", control_delta.get("control2_dx", 0.0))),
                float(control_delta.get("c2_dy", control_delta.get("control2_dy", 0.0))),
            )
        curve.setdefault("edit_history", []).append(operation.to_dict())
        updated = True

    curves = list(getattr(piece, "curves", []) or [])
    if not updated and curves:
        for index, curve in enumerate(curves):
            label = str(getattr(curve, "name", getattr(curve, "label", f"curve_{index}")) or f"curve_{index}")
            if label != curve_name:
                continue
            for attr, dx_key, dy_key in (("control1", "c1_dx", "c1_dy"), ("control2", "c2_dx", "c2_dy")):
                point = getattr(curve, attr, None)
                if point is not None:
                    setattr(curve, attr, point.translate(dx=float(control_delta.get(dx_key, 0.0)), dy=float(control_delta.get(dy_key, 0.0))))
            if not hasattr(curve, "edit_history"):
                try:
                    setattr(curve, "edit_history", [])
                except Exception:  # noqa: BLE001
                    pass
            try:
                curve.edit_history.append(operation.to_dict())
            except Exception:  # noqa: BLE001
                pass
            updated = True
            break

    if not updated:
        raise TransformError(f"Curve '{curve_name}' not found in piece '{piece.name}'")


def _apply_metadata(piece: Any, operations: list[TransformOperation], variant: PatternVariant | None) -> None:
    if not hasattr(piece, "metadata") or piece.metadata is None:
        piece.metadata = {}
    piece.metadata["base_pattern_preserved"] = True
    piece.metadata["transformation_history"] = [operation.to_dict() for operation in operations]
    if variant is not None:
        payload = variant.to_dict()
        piece.metadata["editable_variant"] = payload
        piece.metadata["variant"] = payload


def apply_transformations(
    pieces: Iterable[Any],
    transformations: Iterable[TransformOperation] | PatternVariant,
    *,
    variant: PatternVariant | None = None,
) -> list[Any]:
    """Return transformed deep copies of the given pieces.

    The input pieces are never mutated. If a PatternVariant is supplied either as
    the second argument or through ``variant=``, its payload is embedded in piece
    metadata so the edit history can be saved/replayed.
    """

    transformed = copy.deepcopy(list(pieces))

    if isinstance(transformations, PatternVariant):
        variant = transformations
        operations = list(transformations.transformations)
    else:
        operations = list(transformations)

    for operation in operations:
        piece = _find_piece(transformed, operation.piece)

        if operation.type == "move_point":
            if not operation.point:
                raise TransformError("move_point requires point")
            _move_named_point(piece, operation.point, operation.dx, operation.dy)
        elif operation.type == "move_line":
            if operation.start_point and operation.end_point:
                _move_line_by_points(piece, operation.start_point, operation.end_point, operation.dx, operation.dy)
            elif operation.line:
                _move_line_by_label(piece, operation.line, operation.dx, operation.dy)
            else:
                raise TransformError("move_line requires start_point/end_point or line")
        elif operation.type == "scale_line":
            if operation.start_point and operation.end_point:
                _scale_line_by_points(piece, operation.start_point, operation.end_point, operation.factor, operation.anchor)
            elif operation.line:
                _scale_line_by_label(piece, operation.line, operation.factor)
            else:
                raise TransformError("scale_line requires start_point/end_point or line")
        elif operation.type == "adjust_curve":
            if not operation.curve:
                raise TransformError("adjust_curve requires curve")
            _adjust_curve(piece, operation.curve, operation.control_delta, operation)
        else:
            raise TransformError(f"Unsupported transformation: {operation.type}")

    for piece in transformed:
        _apply_metadata(piece, operations, variant)

    return transformed
