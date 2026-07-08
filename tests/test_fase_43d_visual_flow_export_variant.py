from pathlib import Path

from app.controllers.pattern_editor_controller import (
    apply_editor_operation,
    build_move_point_operation,
    export_editor_variant,
    load_editor_pattern,
)


def _get_first_piece_and_point(state):
    piece = state.pieces[0]
    point_name = sorted(piece.points.keys())[0]
    return piece.name, point_name


def _point_xy(state, piece_name: str, point_name: str) -> tuple[float, float]:
    for piece in state.pieces:
        if piece.name == piece_name:
            point = piece.points[point_name]
            return float(point.x), float(point.y)
    raise AssertionError(f"Piece {piece_name!r} not found")


def test_visual_flow_can_save_and_export_transformed_variant(tmp_path, monkeypatch):
    monkeypatch.chdir(tmp_path)

    state = load_editor_pattern(
        garment_code="pantalon_basico",
        measurements={
            "waist": 84.0,
            "hip": 104.0,
            "outseam": 100.0,
        },
        variant_name="variante_visual_test",
    )

    piece_name, point_name = _get_first_piece_and_point(state)
    initial_x, initial_y = _point_xy(state, piece_name, point_name)

    state = apply_editor_operation(
        state,
        build_move_point_operation(
            piece=piece_name,
            point=point_name,
            dx=0.5,
            dy=-0.5,
        ),
    )

    moved_x, moved_y = _point_xy(state, piece_name, point_name)
    assert moved_x == initial_x + 0.5
    assert moved_y == initial_y - 0.5
    assert len(state.variant.transformations) == 1

    summary = export_editor_variant(
        state,
        output_name="fase_43d_variante_visual_test",
        output_dir=Path("exports"),
    )

    assert summary.variant_json_path.exists()
    assert summary.svg_path is not None and summary.svg_path.exists()
    assert summary.dxf_path is not None and summary.dxf_path.exists()
    assert summary.pdf_path is not None and summary.pdf_path.exists()

    assert summary.variant_json_path.suffix == ".json"
    assert summary.svg_path.suffix == ".svg"
    assert summary.dxf_path.suffix == ".dxf"
    assert summary.pdf_path.suffix == ".pdf"
