from app.controllers.pattern_editor_controller import (
    apply_editor_operation,
    build_move_point_operation,
    load_editor_pattern,
)


def _get_first_piece_and_point(state):
    piece = state.pieces[0]
    point_name = sorted(piece.points.keys())[0]
    return piece.name, point_name


def _point_x(state, piece_name: str, point_name: str) -> float:
    for piece in state.pieces:
        if piece.name == piece_name:
            return float(piece.points[point_name].x)
    raise AssertionError(f"Piece {piece_name!r} not found")


def test_move_point_left_after_right_is_incremental_not_erratic_with_real_pattern():
    state = load_editor_pattern(
        garment_code="pantalon_basico",
        measurements={
            "waist": 84.0,
            "hip": 104.0,
            "outseam": 100.0,
        },
        variant_name="test_incremental_keyboard_move",
    )

    piece_name, point_name = _get_first_piece_and_point(state)
    initial_x = _point_x(state, piece_name, point_name)

    for _ in range(3):
        state = apply_editor_operation(
            state,
            build_move_point_operation(
                piece=piece_name,
                point=point_name,
                dx=0.5,
                dy=0.0,
            ),
        )

    assert _point_x(state, piece_name, point_name) == initial_x + 1.5

    for _ in range(3):
        state = apply_editor_operation(
            state,
            build_move_point_operation(
                piece=piece_name,
                point=point_name,
                dx=-0.5,
                dy=0.0,
            ),
        )

    assert _point_x(state, piece_name, point_name) == initial_x
    assert len(state.variant.transformations) == 6
