from pathlib import Path


def test_canvas_keyboard_move_delegates_to_main_window_contract():
    source = Path("app/gui/pattern_canvas.py").read_text(encoding="utf-8")

    assert "PointMoveCallback" in source
    assert "<Left>" in source
    assert "<Right>" in source
    assert "<Up>" in source
    assert "<Down>" in source
    assert "_request_keyboard_move" in source
    assert "_on_point_move_requested(piece_name, point_name" in source


def test_main_window_uses_move_point_contract_for_canvas_keyboard_move():
    source = Path("app/gui/universal_main_window.py").read_text(encoding="utf-8")

    assert "on_point_move_requested=self._on_canvas_point_move_requested" in source
    assert "build_move_point_operation(" in source
    assert "apply_editor_operation(self.editor_state, operation)" in source
    assert "Operacion registrada como transformacion no destructiva." in source
