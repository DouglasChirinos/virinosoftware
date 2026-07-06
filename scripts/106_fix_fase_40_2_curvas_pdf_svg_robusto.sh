#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="/home/antares/Proyecto/motor"
BRANCH_NAME="feature/fase-40-gui-generacion-exportacion-serializables"

cd "$PROJECT_DIR"

echo "== Fix Fase 40.2: parche robusto para curvas en PDF/SVG =="
echo "== Rol operativo =="
echo "Arquitecto/consultor tecnico del producto + experto en patronaje."

current_branch="$(git branch --show-current)"
if [ "$current_branch" != "$BRANCH_NAME" ]; then
  echo "ERROR: rama actual inesperada: $current_branch"
  echo "Esperado: $BRANCH_NAME"
  exit 1
fi

echo "== Estado Git antes del fix =="
git status --short

mkdir -p engine/exports docs tests scripts

cat > engine/exports/visual_curves.py <<'PY'
from __future__ import annotations

from dataclasses import dataclass
from typing import Any

from engine.geometry.point import Point
from engine.patterns.piece import PatternPiece


@dataclass(frozen=True)
class VisualCurve:
    label: str
    start: Point
    control1: Point
    control2: Point
    end: Point
    kind: str = "visual_curve"


def _point_from_any(value: Any) -> Point:
    if isinstance(value, Point):
        return value
    if hasattr(value, "x") and hasattr(value, "y"):
        return Point(float(value.x), float(value.y))
    if isinstance(value, dict):
        if "x" in value and "y" in value:
            return Point(float(value["x"]), float(value["y"]))
        return Point(float(value[0]), float(value[1]))
    return Point(float(value[0]), float(value[1]))


def _piece_points(piece: PatternPiece) -> dict[str, Point]:
    return {name: _point_from_any(point) for name, point in piece.points.items()}


def _curve_metadata(curves: list[VisualCurve]) -> list[dict[str, Any]]:
    payload: list[dict[str, Any]] = []
    for curve in curves:
        payload.append(
            {
                "label": curve.label,
                "kind": curve.kind,
                "start": {"x": curve.start.x, "y": curve.start.y},
                "control1": {"x": curve.control1.x, "y": curve.control1.y},
                "control2": {"x": curve.control2.x, "y": curve.control2.y},
                "end": {"x": curve.end.x, "y": curve.end.y},
            }
        )
    return payload


def _has(points: dict[str, Point], *names: str) -> bool:
    return all(name in points for name in names)


def _basic_skirt_curves(piece: PatternPiece) -> list[VisualCurve]:
    points = _piece_points(piece)
    if not _has(points, "B_cintura_costado", "D_cadera_costado"):
        return []
    start = points["B_cintura_costado"]
    end = points["D_cadera_costado"]
    dx = max((end.x - start.x) * 0.35, 0.8)
    return [
        VisualCurve(
            label="Curva cadera costado",
            start=start,
            control1=Point(start.x + dx, start.y + 6.0),
            control2=Point(end.x, end.y - 6.0),
            end=end,
        )
    ]


def _evase_curves(piece: PatternPiece) -> list[VisualCurve]:
    points = _piece_points(piece)
    if not _has(points, "D", "C"):
        return []
    start = points["D"]
    end = points["C"]
    depth = max(abs(end.x - start.x) * 0.03, 0.8)
    return [
        VisualCurve(
            label="Correccion suave de bajo",
            start=start,
            control1=Point(start.x + (end.x - start.x) * 0.33, start.y + depth),
            control2=Point(start.x + (end.x - start.x) * 0.66, start.y + depth),
            end=end,
        )
    ]


def _pants_curves(piece: PatternPiece) -> list[VisualCurve]:
    points = _piece_points(piece)
    if len(points) < 4:
        return []

    top_y = min(point.y for point in points.values())
    bottom_y = max(point.y for point in points.values())
    height = max(bottom_y - top_y, 1.0)
    rightmost = max(points.values(), key=lambda point: point.x)
    top_right_candidates = [point for point in points.values() if point.y <= top_y + height * 0.20]
    bottom_right_candidates = [point for point in points.values() if point.y >= top_y + height * 0.75]

    if not top_right_candidates or not bottom_right_candidates:
        return []

    top_right = max(top_right_candidates, key=lambda point: point.x)
    bottom_right = max(bottom_right_candidates, key=lambda point: point.x)
    return [
        VisualCurve(
            label="Curva tiro/costado MVP",
            start=top_right,
            control1=Point(rightmost.x + 1.8, top_right.y + height * 0.25),
            control2=Point(rightmost.x + 1.8, rightmost.y + height * 0.10),
            end=rightmost,
        ),
        VisualCurve(
            label="Curva entrepierna MVP",
            start=rightmost,
            control1=Point(rightmost.x - 1.0, rightmost.y + height * 0.15),
            control2=Point(bottom_right.x + 0.8, bottom_right.y - height * 0.20),
            end=bottom_right,
        ),
    ]


def _short_curves(piece: PatternPiece) -> list[VisualCurve]:
    points = _piece_points(piece)
    if not _has(points, "B", "C"):
        return []
    start = points["B"]
    end = points["C"]
    height = max(end.y - start.y, 1.0)
    return [
        VisualCurve(
            label="Curva tiro/entrepierna MVP",
            start=start,
            control1=Point(start.x + 1.4, start.y + height * 0.30),
            control2=Point(end.x + 1.4, end.y - height * 0.25),
            end=end,
        )
    ]


def build_piece_visual_curves(piece: PatternPiece, garment_code: str) -> list[VisualCurve]:
    code = garment_code.strip().lower()
    if code == "falda_basica":
        return _basic_skirt_curves(piece)
    if code == "falda_evase":
        return _evase_curves(piece)
    if code == "pantalon_basico":
        return _pants_curves(piece)
    if code == "short_basico":
        return _short_curves(piece)
    return []


def attach_visual_curves(pieces: list[PatternPiece], garment_code: str) -> None:
    for piece in pieces:
        curves = build_piece_visual_curves(piece, garment_code)
        if curves:
            piece.metadata["visual_curves"] = _curve_metadata(curves)
            piece.metadata["curve_status"] = "mvp_visual_not_industrial"
PY

python3 - <<'PY'
from pathlib import Path

path = Path("engine/generation/exporter.py")
text = path.read_text(encoding="utf-8")

if "from engine.exports.visual_curves import attach_visual_curves" not in text:
    text = text.replace(
        "from engine.exports.svg.writer import export_svg\n",
        "from engine.exports.svg.writer import export_svg\nfrom engine.exports.visual_curves import attach_visual_curves\n",
        1,
    )

if "attach_visual_curves(pieces, generation_result.garment_code)" not in text:
    marker = "_attach_export_metadata(pieces, generation_result)\n"
    if marker not in text:
        raise SystemExit("ERROR: no se encontro _attach_export_metadata para insertar curvas")
    text = text.replace(
        marker,
        marker + "    attach_visual_curves(pieces, generation_result.garment_code)\n",
        1,
    )

path.write_text(text, encoding="utf-8")
PY

python3 - <<'PY'
from pathlib import Path

path = Path("engine/exports/svg/writer.py")
text = path.read_text(encoding="utf-8")

if "def _curve_elements" not in text:
    curve_func = """
def _curve_elements(tx: Any, ty: Any, curve: dict[str, Any]) -> list[str]:
    start = curve.get("start", {})
    control1 = curve.get("control1", {})
    control2 = curve.get("control2", {})
    end = curve.get("end", {})
    label = escape(str(curve.get("label", "") or ""))

    x1 = tx(float(start.get("x", 0.0)))
    y1 = ty(float(start.get("y", 0.0)))
    cx1 = tx(float(control1.get("x", 0.0)))
    cy1 = ty(float(control1.get("y", 0.0)))
    cx2 = tx(float(control2.get("x", 0.0)))
    cy2 = ty(float(control2.get("y", 0.0)))
    x2 = tx(float(end.get("x", 0.0)))
    y2 = ty(float(end.get("y", 0.0)))
    label_x = (x1 + x2) / 2 + 4
    label_y = (y1 + y2) / 2 - 4

    return [
        (
            f'<path d="M {x1:.2f} {y1:.2f} C {cx1:.2f} {cy1:.2f}, '
            f'{cx2:.2f} {cy2:.2f}, {x2:.2f} {y2:.2f}" '
            f'stroke="black" fill="none" stroke-width="1.6" stroke-dasharray="6 3"/>'
        ),
        f'<text x="{label_x:.2f}" y="{label_y:.2f}" font-size="10" fill="black">{label}</text>',
    ]


"""
    marker = "def _dimension_elements"
    if marker in text:
        index = text.index(marker)
        text = text[:index] + curve_func + text[index:]
    else:
        marker = "def export_svg"
        if marker not in text:
            raise SystemExit("ERROR: no se encontro punto de insercion en SVG writer")
        index = text.index(marker)
        text = text[:index] + curve_func + text[index:]

if 'get("visual_curves"' not in text:
    marker = '        for dim in (piece.metadata or {}).get("dimension_annotations", []):\n'
    index = text.find(marker)
    if index != -1:
        next_for = text.find("\n        for ", index + len(marker))
        if next_for == -1:
            next_for = text.find("\n        occupied:", index + len(marker))
        if next_for == -1:
            raise SystemExit("ERROR: no se pudo ubicar fin del bloque de dimensiones SVG")
        text = (
            text[:next_for]
            + '\n\n        for curve in (piece.metadata or {}).get("visual_curves", []):\n'
            + '            lines.extend(_curve_elements(tx, ty, curve))'
            + text[next_for:]
        )
    else:
        marker = '        occupied: list[tuple[float, float, float, float]] = []\n'
        if marker not in text:
            raise SystemExit("ERROR: no se encontro bloque para insertar curvas SVG")
        text = text.replace(
            marker,
            '        for curve in (piece.metadata or {}).get("visual_curves", []):\n'
            '            lines.extend(_curve_elements(tx, ty, curve))\n\n'
            + marker,
            1,
        )

path.write_text(text, encoding="utf-8")
PY

python3 - <<'PY'
from pathlib import Path

path = Path("engine/exports/pdf/writer.py")
text = path.read_text(encoding="utf-8")

if "def _draw_curve" not in text:
    curve_func = """
def _draw_curve(canvas: Any, tx: Any, ty: Any, curve: dict[str, Any]) -> None:
    start = curve.get("start", {})
    control1 = curve.get("control1", {})
    control2 = curve.get("control2", {})
    end = curve.get("end", {})
    label = str(curve.get("label", "") or "")

    x1 = tx(float(start.get("x", 0.0)))
    y1 = ty(float(start.get("y", 0.0)))
    cx1 = tx(float(control1.get("x", 0.0)))
    cy1 = ty(float(control1.get("y", 0.0)))
    cx2 = tx(float(control2.get("x", 0.0)))
    cy2 = ty(float(control2.get("y", 0.0)))
    x2 = tx(float(end.get("x", 0.0)))
    y2 = ty(float(end.get("y", 0.0)))

    path = canvas.beginPath()
    path.moveTo(x1, y1)
    path.curveTo(cx1, cy1, cx2, cy2, x2, y2)

    canvas.setDash(5, 3)
    canvas.setLineWidth(0.8)
    canvas.drawPath(path, stroke=1, fill=0)
    canvas.setDash()

    canvas.setFont("Helvetica", 6.5)
    canvas.drawString((x1 + x2) / 2 + 3, (y1 + y2) / 2 + 3, label)


"""
    marker = "def _draw_dimension"
    if marker in text:
        index = text.index(marker)
        text = text[:index] + curve_func + text[index:]
    else:
        marker = "def export_pdf"
        if marker not in text:
            raise SystemExit("ERROR: no se encontro punto de insercion en PDF writer")
        index = text.index(marker)
        text = text[:index] + curve_func + text[index:]

if 'get("visual_curves"' not in text:
    marker = '        for dim in (piece.metadata or {}).get("dimension_annotations", []):\n'
    index = text.find(marker)
    if index != -1:
        next_for = text.find("\n        for ", index + len(marker))
        if next_for == -1:
            next_for = text.find("\n        c.setDash()", index + len(marker))
        if next_for == -1:
            raise SystemExit("ERROR: no se pudo ubicar fin del bloque de dimensiones PDF")
        text = (
            text[:next_for]
            + '\n\n        for curve in (piece.metadata or {}).get("visual_curves", []):\n'
            + '            _draw_curve(c, tx, ty, curve)'
            + text[next_for:]
        )
    else:
        marker = '        c.setDash()\n'
        last_index = text.rfind(marker)
        if last_index == -1:
            raise SystemExit("ERROR: no se encontro bloque para insertar curvas PDF")
        text = (
            text[:last_index]
            + '        for curve in (piece.metadata or {}).get("visual_curves", []):\n'
            + '            _draw_curve(c, tx, ty, curve)\n\n'
            + text[last_index:]
        )

path.write_text(text, encoding="utf-8")
PY

cat > tests/test_fase_40_2_visual_curves.py <<'PY'
from __future__ import annotations

from engine.generation import PatternExportRequest, PatternGenerationRequest, export_generated_pattern


def _export_svg_text(tmp_path, garment_code: str, measurements: dict[str, float], options: dict | None = None) -> str:
    result = export_generated_pattern(
        PatternExportRequest(
            generation_request=PatternGenerationRequest(
                garment_code=garment_code,
                measurements=measurements,
                options=options or {},
            ),
            output_name=f"{garment_code}_curves_test",
            output_dir=tmp_path / garment_code,
            export_dxf=False,
            export_pdf=False,
        )
    )

    assert result.svg_path is not None
    return result.svg_path.read_text(encoding="utf-8")


def test_falda_basica_svg_exports_hip_curve(tmp_path) -> None:
    content = _export_svg_text(
        tmp_path,
        "falda_basica",
        {"waist": 73, "hip": 99, "skirt_length": 60, "ease": 2},
        {"full_pattern": True},
    )

    assert "<path" in content
    assert "Curva cadera costado" in content


def test_falda_evase_svg_exports_hem_curve(tmp_path) -> None:
    content = _export_svg_text(
        tmp_path,
        "falda_evase",
        {"waist": 73, "hip": 99, "skirt_length": 60, "ease": 12},
    )

    assert "<path" in content
    assert "Correccion suave de bajo" in content


def test_pantalon_basico_svg_exports_mvp_rise_curve(tmp_path) -> None:
    content = _export_svg_text(
        tmp_path,
        "pantalon_basico",
        {"waist": 84, "hip": 104, "outseam": 100, "inseam": 76},
    )

    assert "<path" in content
    assert "Curva tiro/costado MVP" in content


def test_short_basico_svg_exports_mvp_rise_curve(tmp_path) -> None:
    content = _export_svg_text(
        tmp_path,
        "short_basico",
        {"waist": 84, "hip": 104, "outseam": 45, "inseam": 20},
    )

    assert "<path" in content
    assert "Curva tiro/entrepierna MVP" in content
PY

cat > docs/58_Fase_40_2_Curvas_Patronaje_MVP.md <<'MD'
# Fase 40.2 - Curvas de patronaje MVP

Fecha: 2026-07-05

## Roles obligatorios del asistente en este proyecto

### Rol 1 - Arquitecto / consultor tecnico del producto

Responsabilidad:

- Validar si lo generado sirve realmente para usuario final.
- No cerrar fases solo porque los tests pasan.
- Detectar inconsistencias funcionales, visuales, tecnicas y de flujo antes de cerrar una fase.

### Rol 2 - Experto en patronaje

Responsabilidad:

- Validar que los patrones generados tengan sentido tecnico de patronaje.
- Revisar piezas necesarias, proporciones, medidas de entrada vs cotas reales, curvas y usabilidad.
- Diferenciar MVP geometrico de patron industrial.

## Decision tecnica

Se introduce una capa de curvas visuales MVP para evolucionar el motor desde poligonos rectos hacia patronaje mas real.

Esta fase no convierte automaticamente las prendas en patrones industriales.

## Alcance aplicado

- Soporte SVG/PDF para curvas visuales tipo Bezier.
- Curva de cadera para `falda_basica`.
- Correccion suave de bajo para `falda_evase`.
- Curva MVP de tiro/costado para `pantalon_basico`.
- Curva MVP de tiro/entrepierna para `short_basico`.
- Tests de exportacion SVG con curvas.

## DXF

El soporte DXF queda documentado como pendiente de endurecimiento industrial. La exportacion principal validada en esta fase es SVG/PDF visual. El DXF conserva las lineas base del patron.

## Advertencia de patronaje

Las curvas de esta fase son refinamientos visuales y estructurales iniciales.

Pendientes industriales:

- pantalon: gancho delantero/posterior, tiro, rodilla, bota, entrepierna real.
- short: tiro delantero/posterior, curva de gancho, boca de pierna y entrepierna.
- falda basica: afinado de cintura/cadera/pinzas.
- falda evase: correccion avanzada de bajo por caida.

## Criterio de aceptacion

```text
make validate-fase-40-2
```

Debe validar:

- SVG exporta curvas.
- Las curvas aparecen en prendas actuales.
- El flujo de completitud de piezas sigue OK.
MD

python3 - <<'PY'
from pathlib import Path

path = Path("Makefile")
text = path.read_text(encoding="utf-8")

if "validate-fase-40-2:" not in text:
    if not text.endswith("\n"):
        text += "\n"
    text += "\nvalidate-fase-40-2:\n"
    text += "\t.venv/bin/python -m pytest tests/test_fase_40_2_visual_curves.py -q\n"
    text += "\t.venv/bin/python -m pytest tests/test_fase_40_1a_piece_completeness.py tests/test_fase_40_1b_serializable_complete_pieces.py -q\n"
    text += "\t.venv/bin/python scripts/validate_piece_completeness.py\n"

if ".PHONY:" in text:
    lines = text.splitlines()
    for i, line in enumerate(lines):
        if line.startswith(".PHONY:") and "validate-fase-40-2" not in line:
            lines[i] = line + " validate-fase-40-2"
            break
    text = "\n".join(lines) + "\n"

path.write_text(text, encoding="utf-8")
PY

echo "== Validacion Fase 40.2 =="
make validate-fase-40-2

echo "== Validacion Fase 40.1B sigue OK =="
make validate-fase-40-1b

echo "== Limpieza de exports generados por validacion =="
rm -rf exports

echo "== Estado Git despues del fix =="
git status --short

echo "== Fix/Fase 40.2 aplicado correctamente =="
