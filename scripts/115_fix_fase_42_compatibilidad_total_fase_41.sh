#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="/home/antares/Proyecto/motor"
cd "$PROJECT_DIR"

echo "== Fix Fase 42: compatibilidad completa con contrato Fase 41 =="
echo "== Objetivo =="
echo "- Fase 42 no puede romper TransformOperation/apply_transformations de Fase 41."
echo "- Restaurar soporte move_point, move_line, scale_line, adjust_curve, variant metadata y TransformError."

echo "== Estado Git antes del fix =="
git status --short || true

mkdir -p engine/transformations docs

cat > engine/transformations/operations.py <<'PY'
"""Contrato de operaciones editables para variantes de patron.

Fase 41 define una capa replayable de transformaciones. Fase 42 puede usarla
para GUI, pero no debe modificar el patron base ni romper el contrato publico.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any, Mapping, Sequence


@dataclass(frozen=True)
class TransformOperation:
    """Operacion editable sobre una pieza de patron.

    Operaciones MVP:
    - move_point: mueve un punto nominal.
    - move_line: mueve dos puntos nominales como linea.
    - scale_line: escala una linea desde un ancla.
    - adjust_curve: mueve controles Bezier de una curva estructural.
    """

    type: str
    piece: str
    point: str | None = None
    start_point: str | None = None
    end_point: str | None = None
    curve: str | None = None
    dx: float = 0.0
    dy: float = 0.0
    factor: float | None = None
    anchor: str = "start"
    control_delta: Mapping[str, float] = field(default_factory=dict)

    def to_dict(self) -> dict[str, Any]:
        data: dict[str, Any] = {"type": self.type, "piece": self.piece}
        for key in (
            "point",
            "start_point",
            "end_point",
            "curve",
            "dx",
            "dy",
            "factor",
            "anchor",
            "control_delta",
        ):
            value = getattr(self, key)
            if value is None:
                continue
            if key == "control_delta" and not value:
                continue
            data[key] = dict(value) if isinstance(value, Mapping) else value
        return data


@dataclass(frozen=True)
class PatternVariant:
    """Variante editable sin mutar el patron base."""

    pattern_id: str
    base_garment: str
    variant_name: str
    transformations: Sequence[TransformOperation] = field(default_factory=tuple)

    def to_dict(self) -> dict[str, Any]:
        return {
            "pattern_id": self.pattern_id,
            "base_garment": self.base_garment,
            "variant_name": self.variant_name,
            "transformations": [operation.to_dict() for operation in self.transformations],
        }
PY

cat > engine/transformations/apply.py <<'PY'
"""Aplicador de transformaciones editables sobre copias del patron.

Contrato clave:
- No mutar el patron base.
- Registrar metadata replayable.
- Lanzar TransformError con mensajes estables para tests y GUI.
"""

from __future__ import annotations

from copy import deepcopy
from math import hypot
from typing import Any, Iterable, Sequence

from engine.geometry.point import Point
from engine.transformations.operations import PatternVariant, TransformOperation


class TransformError(ValueError):
    """Error controlado al aplicar transformaciones de patron."""


def _point_as_dict(point: Point) -> dict[str, float]:
    return {"x": float(point.x), "y": float(point.y)}


def _same_point(a: Point, b: Point) -> bool:
    return float(a.x) == float(b.x) and float(a.y) == float(b.y)


def _move_point_object(point: Point, dx: float, dy: float) -> Point:
    return Point(float(point.x) + float(dx), float(point.y) + float(dy))


def _replace_line_points(piece: Any, old_point: Point, new_point: Point) -> None:
    """Actualiza lineas que referencian coordenadas antiguas.

    Los objetos de geometria existentes son dataclasses congeladas en algunas
    versiones y mutables en otras. Para mantener compatibilidad se intenta
    reconstruir la linea con el mismo tipo cuando no se puede asignar.
    """

    new_lines = []
    changed = False
    for line in getattr(piece, "lines", []):
        start = new_point if _same_point(line.start, old_point) else line.start
        end = new_point if _same_point(line.end, old_point) else line.end
        if start is not line.start or end is not line.end:
            changed = True
            try:
                line.start = start
                line.end = end
                new_lines.append(line)
            except Exception:
                new_lines.append(type(line)(start=start, end=end))
        else:
            new_lines.append(line)
    if changed:
        piece.lines = new_lines


def _move_named_point(piece: Any, point_name: str, dx: float, dy: float) -> None:
    if point_name not in piece.points:
        raise TransformError(f"Point '{point_name}' not found in piece '{piece.name}'")
    old_point = piece.points[point_name]
    new_point = _move_point_object(old_point, dx, dy)
    piece.points[point_name] = new_point
    _replace_line_points(piece, old_point, new_point)


def _find_piece(pieces: Sequence[Any], piece_name: str) -> Any:
    for piece in pieces:
        if piece.name == piece_name:
            return piece
    raise TransformError(f"Piece '{piece_name}' not found")


def _move_point(piece: Any, operation: TransformOperation) -> None:
    if not operation.point:
        raise TransformError("move_point requires point")
    _move_named_point(piece, operation.point, operation.dx, operation.dy)


def _move_line(piece: Any, operation: TransformOperation) -> None:
    if not operation.start_point or not operation.end_point:
        raise TransformError("move_line requires start_point and end_point")
    _move_named_point(piece, operation.start_point, operation.dx, operation.dy)
    _move_named_point(piece, operation.end_point, operation.dx, operation.dy)


def _scale_line(piece: Any, operation: TransformOperation) -> None:
    if not operation.start_point or not operation.end_point:
        raise TransformError("scale_line requires start_point and end_point")
    if operation.factor is None:
        raise TransformError("scale_line requires factor")
    if operation.start_point not in piece.points:
        raise TransformError(f"Point '{operation.start_point}' not found in piece '{piece.name}'")
    if operation.end_point not in piece.points:
        raise TransformError(f"Point '{operation.end_point}' not found in piece '{piece.name}'")
    if operation.anchor not in {"start", "end"}:
        raise TransformError("scale_line anchor must be 'start' or 'end'")

    start = piece.points[operation.start_point]
    end = piece.points[operation.end_point]

    if operation.anchor == "start":
        anchor_name = operation.start_point
        moving_name = operation.end_point
        anchor_point = start
        moving_point = end
    else:
        anchor_name = operation.end_point
        moving_name = operation.start_point
        anchor_point = end
        moving_point = start

    _ = anchor_name  # semantic marker for readability
    new_moving = Point(
        float(anchor_point.x) + (float(moving_point.x) - float(anchor_point.x)) * float(operation.factor),
        float(anchor_point.y) + (float(moving_point.y) - float(anchor_point.y)) * float(operation.factor),
    )
    old_moving = piece.points[moving_name]
    piece.points[moving_name] = new_moving
    _replace_line_points(piece, old_moving, new_moving)


def _curve_matches(curve: dict[str, Any], curve_name: str) -> bool:
    return curve.get("id") == curve_name or curve.get("intent") == curve_name or curve.get("name") == curve_name


def _adjust_curve(piece: Any, operation: TransformOperation) -> None:
    if not operation.curve:
        raise TransformError("adjust_curve requires curve")
    curves = piece.metadata.get("structural_curves", []) if getattr(piece, "metadata", None) is not None else []
    for curve in curves:
        if not isinstance(curve, dict) or not _curve_matches(curve, operation.curve):
            continue
        delta = operation.control_delta or {}
        for control_key, dx_key, dy_key in (
            ("control1", "c1_dx", "c1_dy"),
            ("control2", "c2_dx", "c2_dy"),
        ):
            control = curve.get(control_key)
            if not isinstance(control, dict):
                continue
            control["x"] = float(control.get("x", 0.0)) + float(delta.get(dx_key, 0.0))
            control["y"] = float(control.get("y", 0.0)) + float(delta.get(dy_key, 0.0))
        return
    raise TransformError(f"Curve '{operation.curve}' not found in piece '{piece.name}'")


def _line_length(piece: Any, start_point: str, end_point: str) -> float:
    start = piece.points[start_point]
    end = piece.points[end_point]
    return hypot(float(end.x) - float(start.x), float(end.y) - float(start.y))


def _operation_to_dict(operation: TransformOperation) -> dict[str, Any]:
    if hasattr(operation, "to_dict"):
        return operation.to_dict()
    return dict(operation.__dict__)


def _attach_metadata(pieces: Sequence[Any], operations: Sequence[TransformOperation], variant: PatternVariant | None) -> None:
    history = [_operation_to_dict(operation) for operation in operations]
    variant_metadata = variant.to_dict() if variant is not None and hasattr(variant, "to_dict") else None
    for piece in pieces:
        if getattr(piece, "metadata", None) is None:
            piece.metadata = {}
        piece.metadata["base_pattern_preserved"] = True
        piece.metadata["transformation_history"] = history
        if variant_metadata is not None:
            piece.metadata["variant"] = variant_metadata


def apply_transformations(
    pieces: Iterable[Any],
    operations: Sequence[TransformOperation],
    *,
    variant: PatternVariant | None = None,
) -> list[Any]:
    """Aplica transformaciones sobre una copia profunda de las piezas."""

    transformed = deepcopy(list(pieces))

    for operation in operations:
        piece = _find_piece(transformed, operation.piece)
        if getattr(piece, "metadata", None) is None:
            piece.metadata = {}

        if operation.type == "move_point":
            _move_point(piece, operation)
        elif operation.type == "move_line":
            _move_line(piece, operation)
        elif operation.type == "scale_line":
            _scale_line(piece, operation)
        elif operation.type == "adjust_curve":
            _adjust_curve(piece, operation)
        else:
            raise TransformError(f"Unknown transformation type: {operation.type}")

    _attach_metadata(transformed, operations, variant)
    return transformed
PY

cat > engine/transformations/__init__.py <<'PY'
"""Transformaciones editables para variantes de patron."""

from engine.transformations.apply import TransformError, apply_transformations
from engine.transformations.operations import PatternVariant, TransformOperation

__all__ = [
    "PatternVariant",
    "TransformError",
    "TransformOperation",
    "apply_transformations",
]
PY

cat > docs/67_Fix_Fase_42_Compatibilidad_Total_Fase_41.md <<'MD'
# Fix Fase 42 — Compatibilidad total con contrato Fase 41

## Objetivo

Fase 42 incorpora un editor GUI MVP, pero no puede romper el contrato de transformaciones editables creado en Fase 41.

## Problema

El editor sobrescribio parte de `engine/transformations/apply.py` y dejo fuera elementos del contrato publico:

- `TransformOperation.start_point`
- `TransformOperation.end_point`
- `TransformOperation.factor`
- `TransformOperation.anchor`
- parametro `variant` en `apply_transformations`
- metadata `base_pattern_preserved`
- metadata `transformation_history`
- ajuste correcto de controles Bezier
- mensajes estables de `TransformError`

## Correccion

Se restaura el contrato completo:

- `move_point`
- `move_line`
- `scale_line`
- `adjust_curve`
- `PatternVariant`
- `TransformError`
- `apply_transformations(..., variant=...)`

## Criterio de cierre

Deben pasar:

```bash
make validate-fase-41
make validate-fase-42
```

Fase 42 puede ampliar la interfaz, pero Fase 41 sigue siendo el contrato backend de transformacion.
MD

echo "== Validacion Fase 41 =="
make validate-fase-41

echo "== Validacion Fase 42 =="
make validate-fase-42

echo "== Estado Git despues del fix =="
git status --short || true

echo "FIX_FASE_42_COMPAT_TOTAL_FASE_41_OK"
