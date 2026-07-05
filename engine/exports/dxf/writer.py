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


def _layer_for_line(piece: PatternPiece, line: Line) -> str:
    base = piece.name[:20] or "pattern"
    if line.kind == "seam_allowance":
        return f"{base}_SA"[:31]
    if line.kind == "helper":
        return f"{base}_HELPER"[:31]
    return f"{base}_PATTERN"[:31]


def export_dxf(
    pieces: PatternPiece | list[PatternPiece] | tuple[PatternPiece, ...] | list[Line] | tuple[Line, ...],
    output_path: str | Path,
) -> Path:
    try:
        import ezdxf
    except ImportError as exc:
        raise RuntimeError("Falta ezdxf. Ejecuta: python3 -m pip install -r requirements.txt") from exc

    output = Path(output_path)
    output.parent.mkdir(parents=True, exist_ok=True)

    doc = ezdxf.new("R2010")
    msp = doc.modelspace()

    for piece in _normalize_to_pieces(pieces):
        for line in piece.lines:
            layer = _layer_for_line(piece, line)
            if layer not in doc.layers:
                doc.layers.add(layer)
            msp.add_line(
                (line.start.x, -line.start.y),
                (line.end.x, -line.end.y),
                dxfattribs={"layer": layer},
            )

    doc.saveas(output)
    return output
