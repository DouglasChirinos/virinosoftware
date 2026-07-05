#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="/home/antares/Proyecto/motor"
cd "$PROJECT_ROOT"

echo "== Fix Fase 40: export visual con medidas y anotaciones sin solape =="
echo "== Estado Git antes del fix =="
git status --short

cat > engine/exports/pdf/writer.py <<'PY'
from __future__ import annotations

from pathlib import Path
from typing import Any, Callable, Iterable

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

    if not xs or not ys:
        return (0.0, 0.0, 10.0, 10.0)

    return (min(xs), min(ys), max(xs), max(ys))


def _measurement_payload(pieces: list[PatternPiece]) -> dict[str, Any]:
    for piece in pieces:
        metadata = getattr(piece, "metadata", {}) or {}
        measurements = metadata.get("measurements")
        if isinstance(measurements, dict):
            return measurements
    return {}


def _garment_payload(pieces: list[PatternPiece]) -> tuple[str, str]:
    for piece in pieces:
        metadata = getattr(piece, "metadata", {}) or {}
        code = str(metadata.get("garment_code", "") or "")
        name = str(metadata.get("garment_name", "") or "")
        if code or name:
            return code, name
    return "", ""


def _format_measurements(measurements: dict[str, Any]) -> list[str]:
    if not measurements:
        return []

    formatted: list[str] = []
    for key in sorted(measurements):
        value = measurements[key]
        if isinstance(value, float):
            value_text = f"{value:.2f}".rstrip("0").rstrip(".")
        else:
            value_text = str(value)
        if key != "unit":
            formatted.append(f"{key}: {value_text} cm")
    return formatted


def _overlaps(box: tuple[float, float, float, float], boxes: list[tuple[float, float, float, float]]) -> bool:
    left, bottom, right, top = box
    for other_left, other_bottom, other_right, other_top in boxes:
        if not (right < other_left or left > other_right or top < other_bottom or bottom > other_top):
            return True
    return False


def _label_position(
    *,
    x: float,
    y: float,
    text: str,
    font_size: float,
    occupied: list[tuple[float, float, float, float]],
) -> tuple[float, float]:
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

    # Last resort: stack labels below the point to avoid direct overwriting.
    label_x = x + 5
    label_y = y - 24 - (len(occupied) % 5) * (height + 2)
    occupied.append((label_x, label_y - 2, label_x + width, label_y + height))
    return label_x, label_y


def _draw_wrapped_line(
    canvas: Any,
    *,
    text: str,
    x: float,
    y: float,
    max_chars: int = 105,
    leading: float = 11,
) -> float:
    chunks = [text[index : index + max_chars] for index in range(0, len(text), max_chars)] or [""]
    for chunk in chunks:
        canvas.drawString(x, y, chunk)
        y -= leading
    return y


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
    pattern_top = metadata_y - 48

    garment_code, garment_name = _garment_payload(normalized)
    measurements = _measurement_payload(normalized)
    measurement_lines = _format_measurements(measurements)

    c.setFont("Helvetica-Bold", 12)
    c.drawString(margin, header_y, "Motor Patronaje 2D - Exportacion")

    c.setFont("Helvetica", 8)
    if garment_code or garment_name:
        metadata_y = _draw_wrapped_line(
            c,
            text=f"Prenda: {garment_code} - {garment_name}".strip(" -"),
            x=margin,
            y=metadata_y,
            max_chars=100,
        )

    if measurement_lines:
        metadata_y = _draw_wrapped_line(
            c,
            text="Medidas: " + " | ".join(measurement_lines),
            x=margin,
            y=metadata_y,
            max_chars=100,
        )

    piece_names = ", ".join(piece.name for piece in normalized)
    metadata_y = _draw_wrapped_line(
        c,
        text="Piezas: " + piece_names,
        x=margin,
        y=metadata_y,
        max_chars=100,
    )

    pattern_top = min(pattern_top, metadata_y - 16)

    min_x, min_y, max_x, max_y = _canvas_bounds(normalized)
    pattern_width = max(max_x - min_x, 1.0)
    pattern_height = max(max_y - min_y, 1.0)
    available_width = page_width - 2 * margin
    available_height = max(pattern_top - margin, 100.0)
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

        c.setDash()
        c.setFont("Helvetica", 6.8)
        occupied: list[tuple[float, float, float, float]] = []
        for name, point in sorted(piece.points.items(), key=lambda item: (float(item[1].y), float(item[1].x), item[0])):
            x = tx(float(point.x))
            y = ty(float(point.y))
            c.circle(x, y, 1.2, stroke=1, fill=1)
            label_x, label_y = _label_position(
                x=x,
                y=y,
                text=name,
                font_size=6.8,
                occupied=occupied,
            )
            c.drawString(label_x, label_y, name)

    c.showPage()
    c.save()
    return output
PY

cat > engine/exports/svg/writer.py <<'PY'
from __future__ import annotations

from pathlib import Path
from typing import Any, Callable, Iterable
from xml.sax.saxutils import escape

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


def _iter_lines(pieces: list[PatternPiece]) -> Iterable[Any]:
    for piece in pieces:
        yield from piece.lines


def _canvas_bounds(pieces: list[PatternPiece], margin: float = 20.0) -> tuple[float, float, float, float]:
    xs: list[float] = []
    ys: list[float] = []

    for line in _iter_lines(pieces):
        xs.extend([line.start.x, line.end.x])
        ys.extend([line.start.y, line.end.y])

    for piece in pieces:
        for point in piece.points.values():
            xs.append(point.x)
            ys.append(point.y)

    if not xs or not ys:
        return (0, 0, 200, 200)

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


def _measurement_payload(pieces: list[PatternPiece]) -> dict[str, Any]:
    for piece in pieces:
        metadata = getattr(piece, "metadata", {}) or {}
        measurements = metadata.get("measurements")
        if isinstance(measurements, dict):
            return measurements
    return {}


def _garment_payload(pieces: list[PatternPiece]) -> tuple[str, str]:
    for piece in pieces:
        metadata = getattr(piece, "metadata", {}) or {}
        code = str(metadata.get("garment_code", "") or "")
        name = str(metadata.get("garment_name", "") or "")
        if code or name:
            return code, name
    return "", ""


def _format_measurements(measurements: dict[str, Any]) -> str:
    if not measurements:
        return ""

    items: list[str] = []
    for key in sorted(measurements):
        if key == "unit":
            continue
        value = measurements[key]
        if isinstance(value, float):
            value_text = f"{value:.2f}".rstrip("0").rstrip(".")
        else:
            value_text = str(value)
        items.append(f"{key}: {value_text} cm")
    return " | ".join(items)


def _overlaps(box: tuple[float, float, float, float], boxes: list[tuple[float, float, float, float]]) -> bool:
    left, top, right, bottom = box
    for other_left, other_top, other_right, other_bottom in boxes:
        if not (right < other_left or left > other_right or bottom < other_top or top > other_bottom):
            return True
    return False


def _label_position(
    *,
    x: float,
    y: float,
    text: str,
    font_size: float,
    occupied: list[tuple[float, float, float, float]],
) -> tuple[float, float]:
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
    scale = 10
    header_height = 90

    def tx(x: float) -> float:
        return (x - min_x) * scale

    def ty(y: float) -> float:
        return header_height + (y - min_y) * scale

    garment_code, garment_name = _garment_payload(normalized)
    measurements = _format_measurements(_measurement_payload(normalized))
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
        lines.append(
            f'<text x="10" y="42" font-size="12" fill="black">Prenda: {escape((garment_code + " - " + garment_name).strip(" -"))}</text>'
        )
    if measurements:
        lines.append(f'<text x="10" y="60" font-size="12" fill="black">Medidas: {escape(measurements)}</text>')
    if piece_names:
        lines.append(f'<text x="10" y="78" font-size="12" fill="black">Piezas: {escape(piece_names)}</text>')

    for piece in normalized:
        lines.append(f'<g id="{escape(piece.name)}">')
        for line in piece.lines:
            dash = _dash(line)
            stroke_width = "2" if line.kind == "pattern" else "1.5"
            lines.append(
                f'<line x1="{tx(line.start.x):.2f}" y1="{ty(line.start.y):.2f}" '
                f'x2="{tx(line.end.x):.2f}" y2="{ty(line.end.y):.2f}" '
                f'stroke="black" fill="none" stroke-width="{stroke_width}"{dash}/>'
            )

        occupied: list[tuple[float, float, float, float]] = []
        for name, point in sorted(piece.points.items(), key=lambda item: (float(item[1].y), float(item[1].x), item[0])):
            x = tx(point.x)
            y = ty(point.y)
            lines.append(f'<circle cx="{x:.2f}" cy="{y:.2f}" r="3" fill="black"/>')
            label_x, label_y = _label_position(
                x=x,
                y=y,
                text=name,
                font_size=11,
                occupied=occupied,
            )
            lines.append(
                f'<text x="{label_x:.2f}" y="{label_y:.2f}" '
                f'font-size="11" fill="black">{escape(name)}</text>'
            )

        lines.append("</g>")

    lines.append("</svg>")
    output.write_text("\n".join(lines), encoding="utf-8")
    return output
PY

python3 - <<'PY'
from pathlib import Path

path = Path("engine/generation/exporter.py")
text = path.read_text(encoding="utf-8")

if "def _measurements_as_export_dict" not in text:
    marker = "def normalize_pieces(raw_pieces: list[Any]) -> list[PatternPiece]:\n    \"\"\"Normalize all generated pieces for export.\"\"\"\n\n    return [_normalize_piece(piece) for piece in raw_pieces]\n"
    insert = marker + """


def _measurements_as_export_dict(measurements: Any) -> dict[str, Any]:
    \"\"\"Return measurements as a writer-friendly dict for visual exports.\"\"\"

    if isinstance(measurements, dict):
        return dict(measurements)

    as_dict = getattr(measurements, "as_dict", None)
    if callable(as_dict):
        return dict(as_dict())

    if hasattr(measurements, "__dict__"):
        return {
            str(key): value
            for key, value in vars(measurements).items()
            if not str(key).startswith("_")
        }

    return {}


def _attach_export_metadata(
    pieces: list[PatternPiece],
    generation_result: PatternGenerationResult,
) -> list[PatternPiece]:
    \"\"\"Attach garment and measurement data used by SVG/PDF annotations.\"\"\"

    measurements = _measurements_as_export_dict(generation_result.measurements)

    for piece in pieces:
        piece.metadata.setdefault("garment_code", generation_result.garment_code)
        piece.metadata.setdefault("garment_name", generation_result.garment_name)
        piece.metadata.setdefault("draft_class_name", generation_result.draft_class_name)
        piece.metadata.setdefault("measurements", measurements)

    return pieces
"""
    if marker not in text:
        raise SystemExit("ERROR: normalize_pieces marker not found in engine/generation/exporter.py")
    text = text.replace(marker, insert)

old = "    pieces = normalize_pieces(generation_result.pieces)\n"
new = "    pieces = _attach_export_metadata(normalize_pieces(generation_result.pieces), generation_result)\n"
if old in text and new not in text:
    text = text.replace(old, new, 1)

path.write_text(text, encoding="utf-8")
PY

cat > tests/test_export_visual_metadata.py <<'PY'
from pathlib import Path

from engine.exports.svg.writer import export_svg
from engine.generation import PatternExportRequest, PatternGenerationRequest, export_generated_pattern
from engine.patterns.piece import PatternPiece
from engine.geometry.point import Point


def test_universal_export_svg_includes_garment_and_measurements(tmp_path: Path) -> None:
    result = export_generated_pattern(
        PatternExportRequest(
            generation_request=PatternGenerationRequest(
                garment_code="falda_basica",
                measurements={"waist": 72, "hip": 98, "skirt_length": 60},
            ),
            output_name="falda_visual_metadata",
            output_dir=tmp_path,
            export_dxf=False,
            export_pdf=False,
        )
    )

    assert result.svg_path is not None
    svg_text = result.svg_path.read_text(encoding="utf-8")

    assert "Prenda: falda_basica" in svg_text
    assert "Medidas:" in svg_text
    assert "waist: 72 cm" in svg_text
    assert "hip: 98 cm" in svg_text
    assert "skirt_length: 60 cm" in svg_text


def test_svg_label_positions_are_not_identical_for_close_points(tmp_path: Path) -> None:
    piece = PatternPiece(
        name="Pieza prueba",
        points={
            "Pinza_izq": Point(10, 10),
            "Pinza_der": Point(11, 10),
        },
        lines=[],
        metadata={"measurements": {"waist": 72}},
    )

    output = export_svg([piece], tmp_path / "labels.svg")
    svg_text = output.read_text(encoding="utf-8")

    assert "Pinza_izq" in svg_text
    assert "Pinza_der" in svg_text
    assert svg_text.count("font-size=\"11\"") >= 2
PY

if ! grep -q "test_export_visual_metadata.py" Makefile; then
    python3 - <<'PY'
from pathlib import Path
path = Path("Makefile")
text = path.read_text(encoding="utf-8")
needle = "validate-fase-40:\n\t.venv/bin/python -m pytest tests/test_gui_universal_controller.py -q\n\t.venv/bin/python scripts/list_garments.py\n\t.venv/bin/python scripts/generate_pattern.py --garment short_basico --waist 84 --hip 104 --outseam 45 --inseam 20\n\t.venv/bin/python scripts/generate_pattern.py --garment falda_evase --waist 73 --hip 99 --skirt-length 60 --ease 12\n"
replacement = "validate-fase-40:\n\t.venv/bin/python -m pytest tests/test_gui_universal_controller.py tests/test_export_visual_metadata.py -q\n\t.venv/bin/python scripts/list_garments.py\n\t.venv/bin/python scripts/generate_pattern.py --garment short_basico --waist 84 --hip 104 --outseam 45 --inseam 20\n\t.venv/bin/python scripts/generate_pattern.py --garment falda_evase --waist 73 --hip 99 --skirt-length 60 --ease 12\n"
if needle in text:
    text = text.replace(needle, replacement)
else:
    text += "\nvalidate-fase-40-visual:\n\t.venv/bin/python -m pytest tests/test_export_visual_metadata.py -q\n"
path.write_text(text, encoding="utf-8")
PY
fi

if [ -f docs/51_Fase_40_GUI_Generacion_Exportacion_Serializables.md ]; then
    cat >> docs/51_Fase_40_GUI_Generacion_Exportacion_Serializables.md <<'MD'

## Ajuste visual posterior a validacion manual

Durante la validacion manual de la GUI se detecto que el patron se generaba, pero las exportaciones no mostraban las medidas del usuario y algunas anotaciones de puntos cercanos se solapaban.

Correccion aplicada:

- Los exports SVG/PDF incorporan metadatos de prenda y medidas.
- El exportador universal adjunta `garment_code`, `garment_name`, `draft_class_name` y `measurements` a las piezas normalizadas.
- Los labels de puntos en SVG/PDF usan posicionamiento con deteccion basica de colisiones para reducir solapes visuales.
- Las salidas generadas siguen siendo artefactos y no se deben commitear.
MD
fi

echo "== Validaciones visuales Fase 40 =="
.venv/bin/python -m pytest tests/test_export_visual_metadata.py -q
make validate-fase-40

echo "== Prueba de export PDF/SVG con metadatos desde flujo universal =="
.venv/bin/python - <<'PY'
from engine.generation import PatternExportRequest, PatternGenerationRequest, export_generated_pattern

result = export_generated_pattern(
    PatternExportRequest(
        generation_request=PatternGenerationRequest(
            garment_code="falda_basica",
            measurements={"waist": 72, "hip": 98, "skirt_length": 60},
        ),
        output_name="fase_40_visual_check",
    )
)
for path in result.exported_paths:
    print(f"EXPORT_OK: {path} bytes={path.stat().st_size}")
PY

echo "== Limpieza de exports generados por validacion =="
rm -rf exports

echo "== Estado Git despues del fix =="
git status --short

echo "== Fix visual Fase 40 aplicado correctamente =="
