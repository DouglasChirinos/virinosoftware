from __future__ import annotations

import json
from pathlib import Path

from app.controllers.pattern_editor_controller import (
    apply_editor_operation,
    build_move_point_operation,
    export_editor_variant,
    list_piece_names,
    list_point_names,
    load_editor_pattern,
    save_variant_json,
)


def test_editor_loads_pattern_with_piece_and_point_options() -> None:
    state = load_editor_pattern(
        garment_code="falda_evase",
        measurements={"waist": 73, "hip": 99, "skirt_length": 60, "ease": 12},
        variant_name="Prueba editor",
    )

    pieces = list_piece_names(state)
    assert "Falda evase delantera" in pieces
    assert "Falda evase posterior" in pieces
    assert list_point_names(state, "Falda evase delantera")


def test_move_point_operation_does_not_mutate_base_pattern() -> None:
    state = load_editor_pattern(
        garment_code="falda_evase",
        measurements={"waist": 73, "hip": 99, "skirt_length": 60, "ease": 12},
        variant_name="Mover punto",
    )
    piece_name = "Falda evase delantera"
    point_name = list_point_names(state, piece_name)[0]
    base_piece = next(piece for piece in state.pieces if piece.name == piece_name)
    base_point = base_piece.points[point_name]

    operation = build_move_point_operation(piece=piece_name, point=point_name, dx=2.5, dy=-1.0)
    new_state = apply_editor_operation(state, operation)
    new_piece = next(piece for piece in new_state.pieces if piece.name == piece_name)

    assert base_piece.points[point_name] == base_point
    assert new_piece.points[point_name].x == base_point.x + 2.5
    assert new_piece.points[point_name].y == base_point.y - 1.0
    assert len(new_state.variant.transformations) == 1


def test_variant_json_saves_transformation_history(tmp_path: Path) -> None:
    state = load_editor_pattern(
        garment_code="falda_evase",
        measurements={"waist": 73, "hip": 99, "skirt_length": 60, "ease": 12},
        variant_name="Historial",
    )
    operation = build_move_point_operation(piece="Falda evase delantera", point="A", dx=1, dy=0)
    new_state = apply_editor_operation(state, operation)

    path = save_variant_json(new_state, output_dir=tmp_path)
    payload = json.loads(path.read_text(encoding="utf-8"))

    assert payload["base_garment"] == "falda_evase"
    assert payload["variant_name"] == "Historial"
    assert payload["transformations"][0]["type"] == "move_point"
    assert payload["transformations"][0]["point"] == "A"


def test_editor_exports_transformed_variant(tmp_path: Path) -> None:
    state = load_editor_pattern(
        garment_code="falda_evase",
        measurements={"waist": 73, "hip": 99, "skirt_length": 60, "ease": 12},
        variant_name="Exportar variante",
    )
    operation = build_move_point_operation(piece="Falda evase delantera", point="A", dx=1, dy=0)
    new_state = apply_editor_operation(state, operation)

    summary = export_editor_variant(
        new_state,
        output_name="fase42_editor_variant_test",
        output_dir=tmp_path / "exports",
        export_svg_enabled=True,
        export_dxf_enabled=False,
        export_pdf_enabled=False,
    )

    assert summary.variant_json_path.exists()
    assert summary.svg_path is not None
    assert summary.svg_path.exists()
    assert "<svg" in summary.svg_path.read_text(encoding="utf-8")


def test_universal_gui_source_exposes_editor_controls() -> None:
    source = Path("app/gui/universal_main_window.py").read_text(encoding="utf-8")

    assert "Cargar en editor" in source
    assert "Aplicar move_point" in source
    assert "Guardar variante JSON" in source
    assert "Exportar variante SVG/DXF/PDF" in source
