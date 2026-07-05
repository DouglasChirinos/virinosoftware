from __future__ import annotations

from pathlib import Path
from typing import Iterable
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


def _iter_lines(pieces: list[PatternPiece]) -> Iterable[Line]:
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

    def tx(x: float) -> float:
        return (x - min_x) * scale

    def ty(y: float) -> float:
        return (y - min_y) * scale

    lines: list[str] = [
        '<?xml version="1.0" encoding="UTF-8"?>',
        (
            f'<svg xmlns="http://www.w3.org/2000/svg" '
            f'width="{width * scale:.2f}" height="{height * scale:.2f}" '
            f'viewBox="0 0 {width * scale:.2f} {height * scale:.2f}">'
        ),
        '<rect width="100%" height="100%" fill="white"/>',
    ]

    for piece in normalized:
        lines.append(f'<g id="{escape(piece.name)}" stroke="black" fill="none" stroke-width="2">')
        for line in piece.lines:
            lines.append(
                f'<line x1="{tx(line.start.x):.2f}" y1="{ty(line.start.y):.2f}" '
                f'x2="{tx(line.end.x):.2f}" y2="{ty(line.end.y):.2f}"/>'
            )
        for name, point in piece.points.items():
            lines.append(f'<circle cx="{tx(point.x):.2f}" cy="{ty(point.y):.2f}" r="3" fill="black"/>')
            lines.append(
                f'<text x="{tx(point.x) + 5:.2f}" y="{ty(point.y) - 5:.2f}" '
                f'font-size="12" fill="black">{escape(name)}</text>'
            )
        lines.append(f'<text x="10" y="20" font-size="16" fill="black">{escape(piece.name)}</text>')
        lines.append("</g>")

    lines.append("</svg>")
    output.write_text("\n".join(lines), encoding="utf-8")
    return output
