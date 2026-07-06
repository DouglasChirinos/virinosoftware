from __future__ import annotations

from pathlib import Path
from typing import Any, Iterable
from xml.sax.saxutils import escape

from engine.exports.visual_annotations import displayable_point_names, format_measurements_for_header
from engine.geometry.line import Line
from engine.patterns.piece import PatternPiece
from engine.exports.structural_curves import line_is_replaced_by_structural_curve


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




def _structural_curve_elements(tx: Any, ty: Any, curve: dict[str, Any]) -> list[str]:
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
            f'<path class="structural-curve" d="M {x1:.2f} {y1:.2f} '
            f'C {cx1:.2f} {cy1:.2f}, {cx2:.2f} {cy2:.2f}, {x2:.2f} {y2:.2f}" '
            f'stroke="black" fill="none" stroke-width="2.2"/>'
        ),
        f'<text x="{label_x:.2f}" y="{label_y:.2f}" font-size="10" fill="black">{label}</text>',
    ]


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
        structural_curves = (piece.metadata or {}).get("structural_curves", [])
        for line in piece.lines:
            if line_is_replaced_by_structural_curve(line, structural_curves):
                continue

            dash = _dash(line)
            stroke_width = "2" if line.kind == "pattern" else "1.5"
            lines.append(
                f'<line x1="{tx(float(line.start.x)):.2f}" y1="{ty(float(line.start.y)):.2f}" '
                f'x2="{tx(float(line.end.x)):.2f}" y2="{ty(float(line.end.y)):.2f}" '
                f'stroke="black" fill="none" stroke-width="{stroke_width}"{dash}/>'
            )

        for curve in structural_curves:
            lines.extend(_structural_curve_elements(tx, ty, curve))

        piece_points = list(piece.points.values())
        if piece_points:
            piece_min_x = min(float(point.x) for point in piece_points)
            piece_min_y = min(float(point.y) for point in piece_points)
            lines.append(f'<text x="{tx(piece_min_x):.2f}" y="{ty(piece_min_y) - 12:.2f}" font-size="12" font-weight="bold" fill="black">{escape(piece.name)}</text>')

        for dim in (piece.metadata or {}).get("dimension_annotations", []):
            lines.extend(_dimension_elements(tx, ty, dim))

        for curve in (piece.metadata or {}).get("visual_curves", []):
            lines.extend(_curve_elements(tx, ty, curve))

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
