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
