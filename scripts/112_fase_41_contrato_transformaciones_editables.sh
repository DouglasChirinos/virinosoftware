#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="/home/antares/Proyecto/motor"
BRANCH_NAME="feature/fase-40-gui-generacion-exportacion-serializables"

cd "$PROJECT_DIR"

echo "== Fase 41: contrato de transformaciones editables =="
echo "== Criterio de producto =="
echo "El patron base generado por medidas queda intacto. El usuario trabaja sobre variantes editables."
echo "No se construye un CAD completo todavia; se crea una capa MVP de operaciones trazables."

current_branch="$(git branch --show-current)"
if [ "$current_branch" != "$BRANCH_NAME" ]; then
  echo "ERROR: rama actual inesperada: $current_branch"
  echo "Esperado: $BRANCH_NAME"
  echo "No se aplica el script para evitar tocar una rama incorrecta."
  exit 1
fi

echo "== Estado Git antes del cambio =="
git status --short

mkdir -p engine/transformations docs tests

cat > engine/transformations/__init__.py <<'PY'
"""Editable pattern transformation contract."""

from engine.transformations.operations import PatternVariant, TransformOperation
from engine.transformations.apply import apply_transformations

__all__ = ["PatternVariant", "TransformOperation", "apply_transformations"]
PY

cat > engine/transformations/operations.py <<'PY'
"""Contracts for editable pattern transformations.

The generated pattern is the immutable base. User edits are represented as a
replayable list of operations applied on top of that base to produce a variant.
This keeps parametric generation clean and creates the foundation for a visual
editor in the GUI.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any, Literal

TransformType = Literal["move_point", "move_line", "scale_line", "adjust_curve"]
LineAnchor = Literal["start", "end", "center"]


@dataclass(frozen=True)
class TransformOperation:
    """One user-editable transformation over a generated pattern piece.

    Supported MVP operations:
    - move_point: move one named point by dx/dy.
    - move_line: move a named line or a line defined by start/end point names.
    - scale_line: extend/shorten a line by factor around start, end, or center.
    - adjust_curve: move Bezier control points or endpoints of a structural curve.
    """

    type: TransformType
    piece: str
    point: str | None = None
    line: str | None = None
    start_point: str | None = None
    end_point: str | None = None
    curve: str | None = None
    dx: float = 0.0
    dy: float = 0.0
    factor: float = 1.0
    anchor: LineAnchor = "start"
    control_delta: dict[str, float] = field(default_factory=dict)
    note: str = ""

    def as_dict(self) -> dict[str, Any]:
        payload: dict[str, Any] = {
            "type": self.type,
            "piece": self.piece,
        }
        optional = {
            "point": self.point,
            "line": self.line,
            "start_point": self.start_point,
            "end_point": self.end_point,
            "curve": self.curve,
            "dx": self.dx,
            "dy": self.dy,
            "factor": self.factor,
            "anchor": self.anchor,
            "control_delta": dict(self.control_delta),
            "note": self.note,
        }
        for key, value in optional.items():
            if value not in (None, "", {}, 0.0) or key in {"factor", "anchor"}:
                payload[key] = value
        return payload


@dataclass(frozen=True)
class PatternVariant:
    """Editable variant metadata for a generated pattern."""

    pattern_id: str
    base_garment: str
    variant_name: str
    transformations: tuple[TransformOperation, ...]

    def as_dict(self) -> dict[str, Any]:
        return {
            "pattern_id": self.pattern_id,
            "base_garment": self.base_garment,
            "variant_name": self.variant_name,
            "transformations": [operation.as_dict() for operation in self.transformations],
        }
PY

cat > engine/transformations/apply.py <<'PY'
"""Apply editable transformations over generated pattern pieces."""

from __future__ import annotations

from copy import deepcopy
from math import isclose
from typing import Any, Iterable

from engine.geometry.point import Point
from engine.patterns.piece import PatternPiece
from engine.transformations.operations import PatternVariant, TransformOperation


class TransformError(ValueError):
    """Raised when an editable transformation cannot be applied safely."""


def _point_like(value: Any) -> Point:
    if isinstance(value, Point):
        return value
    if hasattr(value, "x") and hasattr(value, "y"):
        return Point(float(value.x), float(value.y))
    if isinstance(value, dict):
        if "x" in value and "y" in value:
            return Point(float(value["x"]), float(value["y"]))
        return Point(float(value[0]), float(value[1]))
    return Point(float(value[0]), float(value[1]))


def _same_point(a: Point, b: Point, tolerance: float = 1e-9) -> bool:
    return isclose(float(a.x), float(b.x), abs_tol=tolerance) and isclose(float(a.y), float(b.y), abs_tol=tolerance)


def _line_name(line: Any) -> str:
    return str(getattr(line, "name", getattr(line, "label", "")) or "")


def _line_kind(line: Any) -> str:
    return str(getattr(line, "kind", "pattern") or "pattern")


def _make_line_like(line: Any, start: Point, end: Point) -> Any:
    cls = line.__class__
    name = _line_name(line)
    kind = _line_kind(line)

    try:
        return cls(start=start, end=end, label=name, kind=kind)
    except TypeError:
        pass

    try:
        return cls(start=start, end=end, name=name, kind=kind)
    except TypeError:
        pass

    from types import SimpleNamespace

    return SimpleNamespace(start=start, end=end, label=name, name=name, kind=kind)


def _find_piece(pieces: list[PatternPiece], piece_name: str) -> PatternPiece:
    for piece in pieces:
        if piece.name == piece_name:
            return piece
    lowered = piece_name.casefold()
    matches = [piece for piece in pieces if lowered in piece.name.casefold()]
    if len(matches) == 1:
        return matches[0]
    available = ", ".join(piece.name for piece in pieces)
    raise TransformError(f"Piece not found or ambiguous: {piece_name!r}. Available: {available}")


def _replace_line_endpoints_for_moved_point(piece: PatternPiece, old: Point, new: Point) -> None:
    updated = []
    for line in piece.lines:
        start = _point_like(line.start)
        end = _point_like(line.end)
        if _same_point(start, old):
            start = new
        if _same_point(end, old):
            end = new
        updated.append(_make_line_like(line, start, end))
    piece.lines = updated


def _set_piece_point(piece: PatternPiece, point_name: str, new_point: Point) -> None:
    if point_name not in piece.points:
        raise TransformError(f"Point {point_name!r} not found in piece {piece.name!r}")
    old = _point_like(piece.points[point_name])
    piece.points[point_name] = new_point
    _replace_line_endpoints_for_moved_point(piece, old, new_point)


def _move_point(piece: PatternPiece, operation: TransformOperation) -> None:
    if not operation.point:
        raise TransformError("move_point requires operation.point")
    current = _point_like(piece.points.get(operation.point)) if operation.point in piece.points else None
    if current is None:
        raise TransformError(f"Point {operation.point!r} not found in piece {piece.name!r}")
    _set_piece_point(piece, operation.point, current.translate(dx=operation.dx, dy=operation.dy))


def _line_matches_by_points(piece: PatternPiece, line: Any, start_point: str | None, end_point: str | None) -> bool:
    if not start_point or not end_point:
        return False
    if start_point not in piece.points or end_point not in piece.points:
        return False
    expected_start = _point_like(piece.points[start_point])
    expected_end = _point_like(piece.points[end_point])
    start = _point_like(line.start)
    end = _point_like(line.end)
    return (_same_point(start, expected_start) and _same_point(end, expected_end)) or (
        _same_point(start, expected_end) and _same_point(end, expected_start)
    )


def _find_line_index(piece: PatternPiece, operation: TransformOperation) -> int:
    for index, line in enumerate(piece.lines):
        if operation.line and _line_name(line) == operation.line:
            return index
        if _line_matches_by_points(piece, line, operation.start_point, operation.end_point):
            return index
    raise TransformError(
        f"Line not found in piece {piece.name!r}. Use line label or start_point/end_point."
    )


def _points_for_line_operation(piece: PatternPiece, operation: TransformOperation, line: Any) -> tuple[str | None, str | None]:
    start_name = operation.start_point
    end_name = operation.end_point

    if start_name and end_name:
        return start_name, end_name

    start = _point_like(line.start)
    end = _point_like(line.end)
    found_start = None
    found_end = None
    for name, point in piece.points.items():
        normalized = _point_like(point)
        if found_start is None and _same_point(normalized, start):
            found_start = name
        if found_end is None and _same_point(normalized, end):
            found_end = name
    return found_start, found_end


def _move_line(piece: PatternPiece, operation: TransformOperation) -> None:
    index = _find_line_index(piece, operation)
    line = piece.lines[index]
    start = _point_like(line.start).translate(dx=operation.dx, dy=operation.dy)
    end = _point_like(line.end).translate(dx=operation.dx, dy=operation.dy)
    piece.lines[index] = _make_line_like(line, start, end)

    start_name, end_name = _points_for_line_operation(piece, operation, line)
    if start_name:
        piece.points[start_name] = start
    if end_name:
        piece.points[end_name] = end


def _scale_point(origin: Point, point: Point, factor: float) -> Point:
    return Point(origin.x + (point.x - origin.x) * factor, origin.y + (point.y - origin.y) * factor)


def _scale_line(piece: PatternPiece, operation: TransformOperation) -> None:
    if operation.factor <= 0:
        raise TransformError("scale_line requires factor > 0")

    index = _find_line_index(piece, operation)
    line = piece.lines[index]
    start = _point_like(line.start)
    end = _point_like(line.end)

    if operation.anchor == "start":
        new_start = start
        new_end = _scale_point(start, end, operation.factor)
    elif operation.anchor == "end":
        new_start = _scale_point(end, start, operation.factor)
        new_end = end
    elif operation.anchor == "center":
        center = Point((start.x + end.x) / 2.0, (start.y + end.y) / 2.0)
        new_start = _scale_point(center, start, operation.factor)
        new_end = _scale_point(center, end, operation.factor)
    else:
        raise TransformError(f"Unsupported line anchor: {operation.anchor!r}")

    piece.lines[index] = _make_line_like(line, new_start, new_end)
    start_name, end_name = _points_for_line_operation(piece, operation, line)
    if start_name:
        piece.points[start_name] = new_start
    if end_name:
        piece.points[end_name] = new_end


def _apply_delta_to_curve_point(point: dict[str, Any], dx: float, dy: float) -> None:
    point["x"] = float(point.get("x", 0.0)) + dx
    point["y"] = float(point.get("y", 0.0)) + dy


def _adjust_curve(piece: PatternPiece, operation: TransformOperation) -> None:
    if not operation.curve:
        raise TransformError("adjust_curve requires operation.curve")

    curves = piece.metadata.get("structural_curves", [])
    if not isinstance(curves, list):
        raise TransformError(f"Piece {piece.name!r} has invalid structural_curves metadata")

    for curve in curves:
        if not isinstance(curve, dict):
            continue
        label = str(curve.get("label", ""))
        intent = str(curve.get("intent", ""))
        if operation.curve not in {label, intent}:
            continue

        delta = dict(operation.control_delta or {})
        mapping = {
            "start": ("start_dx", "start_dy"),
            "control1": ("c1_dx", "c1_dy"),
            "control2": ("c2_dx", "c2_dy"),
            "end": ("end_dx", "end_dy"),
        }
        for key, (dx_key, dy_key) in mapping.items():
            point = curve.get(key)
            if isinstance(point, dict):
                _apply_delta_to_curve_point(point, float(delta.get(dx_key, 0.0)), float(delta.get(dy_key, 0.0)))
        curve.setdefault("edit_history", []).append(operation.as_dict())
        return

    raise TransformError(f"Curve {operation.curve!r} not found in piece {piece.name!r}")


def _apply_one(pieces: list[PatternPiece], operation: TransformOperation) -> None:
    piece = _find_piece(pieces, operation.piece)
    if operation.type == "move_point":
        _move_point(piece, operation)
    elif operation.type == "move_line":
        _move_line(piece, operation)
    elif operation.type == "scale_line":
        _scale_line(piece, operation)
    elif operation.type == "adjust_curve":
        _adjust_curve(piece, operation)
    else:
        raise TransformError(f"Unsupported transformation type: {operation.type!r}")


def _variant_payload(variant: PatternVariant | None, operations: Iterable[TransformOperation]) -> dict[str, Any]:
    if variant is not None:
        return variant.as_dict()
    return {
        "pattern_id": "ad_hoc_variant",
        "base_garment": "unknown",
        "variant_name": "Variante editable",
        "transformations": [operation.as_dict() for operation in operations],
    }


def apply_transformations(
    pieces: list[PatternPiece],
    operations: Iterable[TransformOperation],
    *,
    variant: PatternVariant | None = None,
) -> list[PatternPiece]:
    """Return transformed copies of pattern pieces without mutating the base."""

    operations_tuple = tuple(operations)
    transformed = deepcopy(pieces)

    for operation in operations_tuple:
        _apply_one(transformed, operation)

    payload = _variant_payload(variant, operations_tuple)
    for piece in transformed:
        piece.metadata = dict(piece.metadata or {})
        piece.metadata["editable_variant"] = payload
        piece.metadata["base_pattern_preserved"] = True

    return transformed
PY

cat > tests/test_fase_41_transformaciones_editables.py <<'PY'
from __future__ import annotations

from engine.geometry.line import Line
from engine.geometry.point import Point
from engine.patterns.piece import PatternPiece
from engine.transformations import PatternVariant, TransformOperation, apply_transformations
from engine.transformations.apply import TransformError


def _piece() -> PatternPiece:
    points = {
        "A": Point(0, 0),
        "B": Point(10, 0),
        "C": Point(10, 20),
        "D": Point(0, 20),
    }
    return PatternPiece(
        name="Pieza prueba delantero",
        points=points,
        lines=[
            Line(points["A"], points["B"], label="cintura", kind="pattern"),
            Line(points["B"], points["C"], label="costado", kind="pattern"),
            Line(points["C"], points["D"], label="bajo", kind="pattern"),
        ],
        metadata={
            "structural_curves": [
                {
                    "label": "Curva estructural de tiro",
                    "intent": "crotch_curve",
                    "start": {"x": 10, "y": 0},
                    "control1": {"x": 8, "y": 5},
                    "control2": {"x": 8, "y": 10},
                    "end": {"x": 10, "y": 20},
                }
            ]
        },
    )


def test_move_point_creates_variant_without_mutating_base() -> None:
    base = _piece()
    transformed = apply_transformations(
        [base],
        [TransformOperation(type="move_point", piece="Pieza prueba delantero", point="B", dx=-2, dy=1)],
    )

    assert base.points["B"] == Point(10, 0)
    assert transformed[0].points["B"] == Point(8, 1)
    assert transformed[0].lines[0].end == Point(8, 1)
    assert transformed[0].metadata["base_pattern_preserved"] is True


def test_move_line_moves_two_named_points() -> None:
    transformed = apply_transformations(
        [_piece()],
        [
            TransformOperation(
                type="move_line",
                piece="Pieza prueba delantero",
                start_point="A",
                end_point="B",
                dx=0,
                dy=3,
            )
        ],
    )

    assert transformed[0].points["A"] == Point(0, 3)
    assert transformed[0].points["B"] == Point(10, 3)
    assert transformed[0].lines[0].start == Point(0, 3)
    assert transformed[0].lines[0].end == Point(10, 3)


def test_scale_line_extends_from_start_anchor() -> None:
    transformed = apply_transformations(
        [_piece()],
        [
            TransformOperation(
                type="scale_line",
                piece="Pieza prueba delantero",
                start_point="A",
                end_point="B",
                factor=1.5,
                anchor="start",
            )
        ],
    )

    assert transformed[0].points["A"] == Point(0, 0)
    assert transformed[0].points["B"] == Point(15, 0)
    assert round(transformed[0].lines[0].length, 4) == 15.0


def test_adjust_curve_moves_bezier_controls() -> None:
    transformed = apply_transformations(
        [_piece()],
        [
            TransformOperation(
                type="adjust_curve",
                piece="Pieza prueba delantero",
                curve="crotch_curve",
                control_delta={"c1_dx": -3, "c1_dy": 0, "c2_dx": -4, "c2_dy": 2},
            )
        ],
    )

    curve = transformed[0].metadata["structural_curves"][0]
    assert curve["control1"] == {"x": 5.0, "y": 5.0}
    assert curve["control2"] == {"x": 4.0, "y": 12.0}
    assert curve["edit_history"][0]["type"] == "adjust_curve"


def test_pattern_variant_metadata_is_replayable() -> None:
    variant = PatternVariant(
        pattern_id="pantalon_basico_001",
        base_garment="pantalon_basico",
        variant_name="Pantalon ajustado tiro posterior",
        transformations=(
            TransformOperation(type="move_point", piece="Pieza prueba delantero", point="B", dx=-2),
        ),
    )
    transformed = apply_transformations([_piece()], variant.transformations, variant=variant)

    payload = transformed[0].metadata["editable_variant"]
    assert payload["pattern_id"] == "pantalon_basico_001"
    assert payload["base_garment"] == "pantalon_basico"
    assert payload["transformations"][0]["type"] == "move_point"


def test_unknown_point_fails_fast() -> None:
    try:
        apply_transformations(
            [_piece()],
            [TransformOperation(type="move_point", piece="Pieza prueba delantero", point="Z", dx=1)],
        )
    except TransformError as exc:
        assert "Point 'Z' not found" in str(exc)
    else:
        raise AssertionError("Expected TransformError")
PY

cat > docs/64_Fase_41_Contrato_Transformaciones_Editables.md <<'MD'
# Fase 41 - Contrato de transformaciones editables

## Decision de producto

El motor ya no debe seguir acumulando solo logica automatica de patronaje. El siguiente salto es permitir que el usuario trabaje sobre una variante editable del patron generado.

La regla base queda fija:

```text
patron_base generado por medidas -> variante editable del usuario
```

El patron base no se destruye. Las transformaciones se guardan como operaciones replayables sobre una copia.

## Alcance MVP

Esta fase no implementa un CAD completo ni un editor visual todavia. Crea el contrato tecnico que hara posible la Fase 42.

Operaciones soportadas:

- `move_point`: mover un punto por `dx/dy`.
- `move_line`: desplazar una linea completa.
- `scale_line`: estirar o acortar una linea con ancla `start`, `end` o `center`.
- `adjust_curve`: mover controles Bezier de una curva estructural.

## Modelo de variante

```json
{
  "pattern_id": "pantalon_basico_001",
  "base_garment": "pantalon_basico",
  "variant_name": "Pantalon ajustado tiro posterior",
  "transformations": [
    {
      "type": "move_point",
      "piece": "Pantalon basico posterior",
      "point": "B",
      "dx": -2.0,
      "dy": 0.0
    },
    {
      "type": "adjust_curve",
      "piece": "Pantalon basico posterior",
      "curve": "crotch_curve",
      "control_delta": {
        "c1_dx": -3.0,
        "c1_dy": 0.0,
        "c2_dx": -5.0,
        "c2_dy": 1.0
      }
    }
  ]
}
```

## Criterio tecnico

- La funcion `apply_transformations` devuelve copias transformadas.
- La geometria base permanece intacta.
- Cada pieza transformada recibe metadata `editable_variant`.
- Las operaciones deben fallar rapido si la pieza, punto, linea o curva no existe.

## Archivos agregados

- `engine/transformations/__init__.py`
- `engine/transformations/operations.py`
- `engine/transformations/apply.py`
- `tests/test_fase_41_transformaciones_editables.py`

## Validacion

```bash
make validate-fase-41
```

## Pendiente para Fase 42

Crear editor visual MVP en GUI:

- Canvas de patron.
- Seleccion de pieza.
- Seleccion de punto, linea o curva.
- Movimiento con mouse o campos numericos.
- Deshacer.
- Guardar variante.
- Exportar variante a SVG/PDF/DXF.
MD

python3 - <<'PY'
from pathlib import Path

path = Path("Makefile")
text = path.read_text(encoding="utf-8")

phony = ".PHONY:"
if phony in text and "validate-fase-41" not in text.split("\n", 1)[0]:
    lines = text.splitlines()
    for index, line in enumerate(lines):
        if line.startswith(".PHONY:") and "validate-fase-41" not in line:
            lines[index] = line + " validate-fase-41"
            break
    text = "\n".join(lines) + "\n"

if "validate-fase-41:" not in text:
    text += """
validate-fase-41:
	.venv/bin/python -m pytest tests/test_fase_41_transformaciones_editables.py -q
"""

path.write_text(text, encoding="utf-8")
PY

echo "== Validacion Fase 41 =="
make validate-fase-41

if grep -q '^validate-fase-40-3d:' Makefile; then
  echo "== Validacion de regresion Fase 40.3D =="
  make validate-fase-40-3d
else
  echo "WARN: target validate-fase-40-3d no existe; se omite regresion 40.3D."
fi

echo "== Estado Git despues del cambio =="
git status --short

echo "== Fase 41 aplicada =="
echo "Siguiente paso: Fase 42 editor visual MVP en GUI usando este contrato."
