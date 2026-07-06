from __future__ import annotations

from engine.geometry.line import Line
from engine.geometry.point import Point
from engine.patterns.piece import PatternPiece
from engine.transformations import PatternVariant, TransformOperation, apply_transformations
from engine.transformations.apply import TransformError


def _piece() -> PatternPiece:
    points = {
        "A": Point(0, 0),
        "B": Point(10, 0),
        "C": Point(10, 20),
        "D": Point(0, 20),
    }
    return PatternPiece(
        name="Pieza prueba delantero",
        points=points,
        lines=[
            Line(points["A"], points["B"], label="cintura", kind="pattern"),
            Line(points["B"], points["C"], label="costado", kind="pattern"),
            Line(points["C"], points["D"], label="bajo", kind="pattern"),
        ],
        metadata={
            "structural_curves": [
                {
                    "label": "Curva estructural de tiro",
                    "intent": "crotch_curve",
                    "start": {"x": 10, "y": 0},
                    "control1": {"x": 8, "y": 5},
                    "control2": {"x": 8, "y": 10},
                    "end": {"x": 10, "y": 20},
                }
            ]
        },
    )


def test_move_point_creates_variant_without_mutating_base() -> None:
    base = _piece()
    transformed = apply_transformations(
        [base],
        [TransformOperation(type="move_point", piece="Pieza prueba delantero", point="B", dx=-2, dy=1)],
    )

    assert base.points["B"] == Point(10, 0)
    assert transformed[0].points["B"] == Point(8, 1)
    assert transformed[0].lines[0].end == Point(8, 1)
    assert transformed[0].metadata["base_pattern_preserved"] is True


def test_move_line_moves_two_named_points() -> None:
    transformed = apply_transformations(
        [_piece()],
        [
            TransformOperation(
                type="move_line",
                piece="Pieza prueba delantero",
                start_point="A",
                end_point="B",
                dx=0,
                dy=3,
            )
        ],
    )

    assert transformed[0].points["A"] == Point(0, 3)
    assert transformed[0].points["B"] == Point(10, 3)
    assert transformed[0].lines[0].start == Point(0, 3)
    assert transformed[0].lines[0].end == Point(10, 3)


def test_scale_line_extends_from_start_anchor() -> None:
    transformed = apply_transformations(
        [_piece()],
        [
            TransformOperation(
                type="scale_line",
                piece="Pieza prueba delantero",
                start_point="A",
                end_point="B",
                factor=1.5,
                anchor="start",
            )
        ],
    )

    assert transformed[0].points["A"] == Point(0, 0)
    assert transformed[0].points["B"] == Point(15, 0)
    assert round(transformed[0].lines[0].length, 4) == 15.0


def test_adjust_curve_moves_bezier_controls() -> None:
    transformed = apply_transformations(
        [_piece()],
        [
            TransformOperation(
                type="adjust_curve",
                piece="Pieza prueba delantero",
                curve="crotch_curve",
                control_delta={"c1_dx": -3, "c1_dy": 0, "c2_dx": -4, "c2_dy": 2},
            )
        ],
    )

    curve = transformed[0].metadata["structural_curves"][0]
    assert curve["control1"] == {"x": 5.0, "y": 5.0}
    assert curve["control2"] == {"x": 4.0, "y": 12.0}
    assert curve["edit_history"][0]["type"] == "adjust_curve"


def test_pattern_variant_metadata_is_replayable() -> None:
    variant = PatternVariant(
        pattern_id="pantalon_basico_001",
        base_garment="pantalon_basico",
        variant_name="Pantalon ajustado tiro posterior",
        transformations=(
            TransformOperation(type="move_point", piece="Pieza prueba delantero", point="B", dx=-2),
        ),
    )
    transformed = apply_transformations([_piece()], variant.transformations, variant=variant)

    payload = transformed[0].metadata["editable_variant"]
    assert payload["pattern_id"] == "pantalon_basico_001"
    assert payload["base_garment"] == "pantalon_basico"
    assert payload["transformations"][0]["type"] == "move_point"


def test_unknown_point_fails_fast() -> None:
    try:
        apply_transformations(
            [_piece()],
            [TransformOperation(type="move_point", piece="Pieza prueba delantero", point="Z", dx=1)],
        )
    except TransformError as exc:
        assert "Point 'Z' not found" in str(exc)
    else:
        raise AssertionError("Expected TransformError")
