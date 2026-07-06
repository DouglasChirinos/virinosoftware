from __future__ import annotations

from pathlib import Path
from typing import Any, Iterable

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




def _draw_structural_curve(canvas: Any, tx: Any, ty: Any, curve: dict[str, Any]) -> None:
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

    canvas.setDash()
    canvas.setLineWidth(1.1)
    canvas.drawPath(path, stroke=1, fill=0)

    canvas.setFont("Helvetica", 6.5)
    canvas.drawString((x1 + x2) / 2 + 3, (y1 + y2) / 2 + 3, label)


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

        for curve in (piece.metadata or {}).get("visual_curves", []):
            _draw_curve(c, tx, ty, curve)
        structural_curves = (piece.metadata or {}).get("structural_curves", [])
        for line in piece.lines:
            if line_is_replaced_by_structural_curve(line, structural_curves):
                continue

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

        for curve in structural_curves:
            _draw_structural_curve(c, tx, ty, curve)

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
