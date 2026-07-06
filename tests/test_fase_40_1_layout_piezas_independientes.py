from __future__ import annotations

from engine.generation import PatternGenerationRequest, generate_pattern
from engine.generation.exporter import _arrange_pieces_for_export, _piece_bounds, normalize_pieces


def test_pantalon_basico_front_and_back_are_visually_separated_after_layout() -> None:
    generation = generate_pattern(
        PatternGenerationRequest(
            garment_code="pantalon_basico",
            measurements={"waist": 84, "hip": 104, "outseam": 100, "inseam": 76},
        )
    )
    pieces = normalize_pieces(generation.pieces)

    # The raw MVP draft starts both pieces from the same local origin.
    raw_front = _piece_bounds(pieces[0])
    raw_back = _piece_bounds(pieces[1])
    assert raw_front[0] == raw_back[0]

    _arrange_pieces_for_export(pieces)

    front = _piece_bounds(pieces[0])
    back = _piece_bounds(pieces[1])

    assert front[2] < back[0]
    assert back[0] - front[2] >= 10


def test_layout_translation_preserves_piece_widths() -> None:
    generation = generate_pattern(
        PatternGenerationRequest(
            garment_code="pantalon_basico",
            measurements={"waist": 84, "hip": 104, "outseam": 100, "inseam": 76},
        )
    )
    pieces = normalize_pieces(generation.pieces)
    raw_widths = [bounds[2] - bounds[0] for bounds in map(_piece_bounds, pieces)]

    _arrange_pieces_for_export(pieces)
    arranged_widths = [bounds[2] - bounds[0] for bounds in map(_piece_bounds, pieces)]

    assert arranged_widths == raw_widths
