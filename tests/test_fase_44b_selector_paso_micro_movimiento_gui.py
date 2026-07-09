from app.gui.pattern_canvas import PatternCanvas
from app.gui.universal_main_window import (
    _fase44b_build_move_deltas,
    _fase44b_normalize_step,
    _fase44b_step_values,
)


class DummyCanvas:
    def __init__(self, selected=("Pieza", "punto")):
        self._selected = selected
        self.moves = []

    @property
    def selected_point(self):
        return self._selected

    def _request_keyboard_move(self, *, dx, dy):
        self.moves.append((dx, dy))


def test_fase44b_declares_allowed_step_values():
    assert _fase44b_step_values() == ("0.1", "0.5", "1.0")


def test_fase44b_normalizes_invalid_step_to_default():
    assert _fase44b_normalize_step("0.1") == 0.1
    assert _fase44b_normalize_step("0.5") == 0.5
    assert _fase44b_normalize_step("1.0") == 1.0
    assert _fase44b_normalize_step("9") == 0.5
    assert _fase44b_normalize_step("bad") == 0.5


def test_fase44b_builds_direction_deltas_from_selected_step():
    assert _fase44b_build_move_deltas(0.5) == {
        "left": (-0.5, 0.0),
        "right": (0.5, 0.0),
        "up": (0.0, -0.5),
        "down": (0.0, 0.5),
    }


def test_fase44b_canvas_exposes_micro_movement_contract():
    assert PatternCanvas.micro_step_values() == (0.1, 0.5, 1.0)
    assert PatternCanvas.normalize_step_cm("0.1") == 0.1
    assert PatternCanvas.normalize_step_cm("bad") == 0.5
    assert hasattr(PatternCanvas, "move_selected_point_by")


def test_fase44b_canvas_micro_move_reuses_keyboard_move_path():
    canvas = DummyCanvas()

    moved = PatternCanvas.move_selected_point_by(canvas, 0.5, -0.5)

    assert moved is True
    assert canvas.moves == [(0.5, -0.5)]


def test_fase44b_canvas_micro_move_without_selection_is_noop():
    canvas = DummyCanvas(selected=None)

    moved = PatternCanvas.move_selected_point_by(canvas, 0.5, 0.0)

    assert moved is False
    assert canvas.moves == []
