from __future__ import annotations

from pathlib import Path

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


def export_pdf(
    pieces: PatternPiece | list[PatternPiece] | tuple[PatternPiece, ...] | list[Line] | tuple[Line, ...],
    output_path: str | Path,
) -> Path:
    try:
        from reportlab.lib.pagesizes import A4
        from reportlab.pdfgen import canvas
    except ImportError as exc:
        raise RuntimeError("Falta reportlab. Ejecuta: python3 -m pip install -r requirements.txt") from exc

    output = Path(output_path)
    output.parent.mkdir(parents=True, exist_ok=True)

    c = canvas.Canvas(str(output), pagesize=A4)
    _page_width, page_height = A4

    scale = 8
    margin = 40
    c.setFont("Helvetica", 12)
    c.drawString(margin, page_height - margin, "Motor Patronaje 2D - Exportacion MVP")

    for piece in _normalize_to_pieces(pieces):
        for line in piece.lines:
            x1 = margin + line.start.x * scale
            y1 = page_height - margin - line.start.y * scale - 30
            x2 = margin + line.end.x * scale
            y2 = page_height - margin - line.end.y * scale - 30

            if line.kind == "seam_allowance":
                c.setDash(4, 3)
                c.setLineWidth(0.7)
            else:
                c.setDash()
                c.setLineWidth(1.0)

            c.line(x1, y1, x2, y2)

        c.setDash()
        c.setFont("Helvetica", 7)
        for name, point in piece.points.items():
            x = margin + point.x * scale
            y = page_height - margin - point.y * scale - 30
            c.circle(x, y, 1.2, stroke=1, fill=1)
            c.drawString(x + 4, y + 4, name)

    c.showPage()
    c.save()
    return output
