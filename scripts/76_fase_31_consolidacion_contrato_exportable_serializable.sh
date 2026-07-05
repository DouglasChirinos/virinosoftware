#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="/home/antares/Proyecto/motor"
PHASE_BRANCH="feature/fase-31-consolidacion-contrato-exportable-serializable"
DOC_PATH="docs/40_Fase_31_Consolidacion_Contrato_Exportable_Serializable.md"
TEST_PATH="tests/test_exporter_serializable_contract.py"
EXPORTER_PATH="engine/generation/exporter.py"

cd "$PROJECT_ROOT"

echo "== Fase 31: Consolidacion contrato exportable serializable / limpieza exporter =="

echo "== Verificando rama =="
CURRENT_BRANCH="$(git branch --show-current)"
if [ "$CURRENT_BRANCH" != "$PHASE_BRANCH" ]; then
  echo "ERROR: rama actual: $CURRENT_BRANCH"
  echo "Debes ejecutar en: $PHASE_BRANCH"
  exit 1
fi

echo "== Verificando estado Git limpio =="
if [ -n "$(git status --short)" ]; then
  echo "ERROR: el arbol de trabajo no esta limpio antes de iniciar Fase 31."
  git status --short
  exit 1
fi

echo "== Verificando base funcional de Fase 30 =="
make test
make export-universal-short

echo "== Refactor controlado de exporter.py =="
python3 - <<'PY'
from pathlib import Path

path = Path("engine/generation/exporter.py")
text = path.read_text(encoding="utf-8")
original = text

# Ensure SimpleNamespace import exists because the normalized serializable contract uses it.
if "from types import SimpleNamespace" not in text:
    lines = text.splitlines()
    insert_at = 0
    for i, line in enumerate(lines):
        if line.startswith("from ") or line.startswith("import "):
            insert_at = i + 1
    lines.insert(insert_at, "from types import SimpleNamespace")
    text = "\n".join(lines) + "\n"

start_marker = "def _is_serializable_line_reference(line):"
end_marker = "def normalize_pieces(raw_pieces: list[Any]) -> list[Any]:"

start = text.find(start_marker)
end = text.find(end_marker)
if start == -1:
    raise SystemExit("ERROR: no se encontro bloque inicial de normalizacion serializable")
if end == -1:
    raise SystemExit("ERROR: no se encontro normalize_pieces")

new_block = '''def _is_point_like(value: Any) -> bool:\n    return hasattr(value, "x") and hasattr(value, "y")\n\n\ndef _is_xy_sequence(value: Any) -> bool:\n    return (\n        isinstance(value, (tuple, list))\n        and len(value) >= 2\n        and not isinstance(value[0], str)\n        and not isinstance(value[1], str)\n    )\n\n\ndef _is_xy_mapping(value: Any) -> bool:\n    return isinstance(value, dict) and (\n        {"x", "y"}.issubset(value.keys()) or {0, 1}.issubset(value.keys())\n    )\n\n\ndef _is_serializable_line_reference(line: Any) -> bool:\n    return (\n        isinstance(line, (tuple, list))\n        and len(line) == 2\n        and isinstance(line[0], str)\n        and isinstance(line[1], str)\n    )\n\n\ndef _is_serializable_line_mapping(line: Any) -> bool:\n    return (\n        isinstance(line, dict)\n        and isinstance(line.get("start"), str)\n        and isinstance(line.get("end"), str)\n    )\n\n\ndef _normalize_point(point: Any) -> Any:\n    if _is_point_like(point):\n        return point\n\n    if _is_xy_sequence(point):\n        return SimpleNamespace(x=float(point[0]), y=float(point[1]))\n\n    if _is_xy_mapping(point):\n        if "x" in point and "y" in point:\n            return SimpleNamespace(x=float(point["x"]), y=float(point["y"]))\n\n        return SimpleNamespace(x=float(point[0]), y=float(point[1]))\n\n    raise PatternExportError(f"Invalid point object: {point!r}")\n\n\ndef _get_serializable_point(points: dict[str, Any], point_name: str) -> Any:\n    if point_name not in points:\n        raise PatternExportError(\n            f"Serializable line reference uses unknown point: {point_name!r}"\n        )\n\n    return _normalize_point(points[point_name])\n\n\ndef _line_from_serializable_reference(\n    points: dict[str, Any],\n    start_name: str,\n    end_name: str,\n    *,\n    name: str = "",\n    kind: str = "pattern",\n) -> Any:\n    return SimpleNamespace(\n        start=_get_serializable_point(points, start_name),\n        end=_get_serializable_point(points, end_name),\n        name=name,\n        kind=kind,\n    )\n\n\ndef _normalize_line(line: Any, points: dict[str, Any] | None = None) -> Any:\n    if _is_serializable_line_reference(line):\n        if not isinstance(points, dict):\n            raise PatternExportError(\n                f"Serializable line reference requires piece.points dict: {line!r}"\n            )\n\n        return _line_from_serializable_reference(points, line[0], line[1])\n\n    if _is_serializable_line_mapping(line):\n        if not isinstance(points, dict):\n            raise PatternExportError(\n                f"Serializable line mapping requires piece.points dict: {line!r}"\n            )\n\n        return _line_from_serializable_reference(\n            points,\n            line["start"],\n            line["end"],\n            name=str(line.get("name", "")),\n            kind=str(line.get("kind", "pattern")),\n        )\n\n    if not hasattr(line, "start") or not hasattr(line, "end"):\n        raise PatternExportError(f"Invalid line object: {line!r}")\n\n    return SimpleNamespace(\n        start=_normalize_point(line.start),\n        end=_normalize_point(line.end),\n        name=getattr(line, "name", ""),\n        kind=getattr(line, "kind", "pattern"),\n    )\n\n\ndef _normalize_piece(piece: Any) -> Any:\n    if not hasattr(piece, "name"):\n        raise PatternExportError(f"Piece without name cannot be exported: {piece!r}")\n\n    if not hasattr(piece, "lines"):\n        raise PatternExportError(f"Piece without lines cannot be exported: {piece!r}")\n\n    source_points = getattr(piece, "points", None)\n    lines = [_normalize_line(line, source_points) for line in piece.lines]\n\n    points = {}\n    for index, line in enumerate(lines, start=1):\n        points[f"line_{index}_start"] = line.start\n        points[f"line_{index}_end"] = line.end\n\n    normalized = SimpleNamespace(\n        name=piece.name,\n        lines=lines,\n        points=points,\n        metadata=dict(getattr(piece, "metadata", {}) or {}),\n    )\n\n    normalized.pattern_lines = [\n        line for line in lines if getattr(line, "kind", "pattern") == "pattern"\n    ]\n    normalized.seam_allowance_lines = [\n        line for line in lines if getattr(line, "kind", "pattern") == "seam_allowance"\n    ]\n\n    return normalized\n\n\n'''

text = text[:start] + new_block + text[end:]

# Collapse excessive blank lines after pattern_generator import if present.
text = text.replace(")\n\n\n\ndef _is_point_like", ")\n\n\ndef _is_point_like")

if text == original:
    raise SystemExit("ERROR: exporter.py no cambio; revisar estado actual")

path.write_text(text, encoding="utf-8")
print("OK: exporter.py normalizado con contrato exportable serializable limpio")
PY

echo "== Creando tests unitarios del contrato exportable serializable =="
cat > "$TEST_PATH" <<'PY'
from types import SimpleNamespace

import pytest

from engine.generation.exporter import PatternExportError, normalize_pieces


def test_normalize_serializable_piece_resolves_tuple_line_references():
    piece = SimpleNamespace(
        name="Short basico delantero",
        points={
            "A": (0.0, 0.0),
            "B": (21.0, 0.0),
        },
        lines=[("A", "B")],
        metadata={"source": "serializable"},
    )

    normalized = normalize_pieces([piece])[0]

    assert normalized.name == "Short basico delantero"
    assert len(normalized.lines) == 1
    assert normalized.lines[0].start.x == 0.0
    assert normalized.lines[0].start.y == 0.0
    assert normalized.lines[0].end.x == 21.0
    assert normalized.lines[0].end.y == 0.0
    assert normalized.metadata == {"source": "serializable"}


def test_normalize_serializable_piece_resolves_mapping_line_references_with_kind():
    piece = SimpleNamespace(
        name="Pieza serializable",
        points={
            "A": {"x": 0, "y": 0},
            "B": [10, 5],
        },
        lines=[{"start": "A", "end": "B", "name": "costado", "kind": "seam_allowance"}],
        metadata={},
    )

    normalized = normalize_pieces([piece])[0]

    assert normalized.lines[0].name == "costado"
    assert normalized.lines[0].kind == "seam_allowance"
    assert normalized.lines[0].start.x == 0.0
    assert normalized.lines[0].end.y == 5.0
    assert normalized.pattern_lines == []
    assert normalized.seam_allowance_lines == normalized.lines


def test_normalize_serializable_piece_rejects_unknown_point_reference():
    piece = SimpleNamespace(
        name="Pieza con error",
        points={"A": (0, 0)},
        lines=[("A", "B")],
        metadata={},
    )

    with pytest.raises(PatternExportError, match="unknown point"):
        normalize_pieces([piece])
PY

echo "== Creando documentacion Fase 31 =="
cat > "$DOC_PATH" <<'MD'
# Fase 31 - Consolidacion del contrato exportable serializable

## Objetivo

Consolidar el contrato tecnico entre prendas serializables JSON y el exportador universal SVG/DXF/PDF.

La Fase 30 dejo funcional la exportacion universal de `short_basico`, pero el `exporter.py` quedo con logica defensiva agregada durante varios fixes. Esta fase limpia y formaliza ese contrato para que futuras prendas JSON no dependan de parches acumulados.

## Alcance

- Refactor controlado de `engine/generation/exporter.py`.
- Consolidacion de helpers internos para puntos y lineas serializables.
- Tests unitarios especificos del contrato exportable serializable.
- Validacion completa de generacion y exportacion existente.
- No se crean prendas nuevas.
- No se toca GUI.
- No se cambia el DSL JSON.

## Contrato exportable soportado

El exportador universal ahora acepta piezas con:

### Puntos

Objetos con atributos:

```python
point.x
point.y
```

Tuplas/listas numericas:

```python
(0.0, 0.0)
[21.0, 0.0]
```

Diccionarios:

```python
{"x": 0.0, "y": 0.0}
```

### Lineas

Lineas clasicas con:

```python
line.start
line.end
```

Referencias serializables por tupla/lista:

```python
("A", "B")
```

Referencias serializables por mapping:

```python
{"start": "A", "end": "B", "name": "costado", "kind": "pattern"}
```

## Archivos modificados

```text
engine/generation/exporter.py
tests/test_exporter_serializable_contract.py
docs/40_Fase_31_Consolidacion_Contrato_Exportable_Serializable.md
scripts/76_fase_31_consolidacion_contrato_exportable_serializable.sh
```

## Validaciones

```bash
make test
make list-garments
make generate-pattern
make generate-basic-pants
make generate-universal-short
make generate-serializable-short
make export-pattern
make export-basic-pants
make export-universal-short
```

## Resultado esperado

```text
short_basico sigue exportando SVG/DXF/PDF por flujo universal.
El contrato serializable queda cubierto con tests unitarios especificos.
No se rompe exportacion tradicional de falda_basica ni pantalon_basico.
```
MD

echo "== Validando sintaxis =="
python3 -m compileall engine/generation/exporter.py

echo "== Ejecutando validaciones completas =="
make test
make list-garments
make generate-pattern
make generate-basic-pants
make generate-universal-short
make generate-serializable-short
make export-pattern
make export-basic-pants
make export-universal-short

echo "== Estado Git =="
git status --short

echo "OK: Fase 31 aplicada y validada."
