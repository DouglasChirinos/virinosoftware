from app.gui.pattern_canvas import ReadOnlyPatternCanvas
from app.gui.universal_main_window import (
    _fase44c_build_reset_result_message,
    _fase44c_build_variant_feedback,
)


def test_fase44c_variant_feedback_messages_are_user_facing():
    assert _fase44c_build_variant_feedback(False) == (
        "Variante activa: sin cambios pendientes."
    )

    dirty = _fase44c_build_variant_feedback(True, reason="Punto movido")
    assert "Variante activa" in dirty
    assert "cambios sin guardar" in dirty
    assert "Punto movido" in dirty


def test_fase44c_reset_result_messages_are_explicit():
    assert "punto restaurado" in _fase44c_build_reset_result_message(True)
    assert "no hay punto seleccionado" in _fase44c_build_reset_result_message(False)


def test_fase44c_selection_helpers_support_dict_contract():
    info = {
        "piece_name": "Pantalon basico delantero",
        "point_name": "Cintura costado",
        "x_cm": 12.5,
        "y_cm": 4.0,
    }

    assert ReadOnlyPatternCanvas._fase44c_selection_key(info) == (
        "Pantalon basico delantero",
        "Cintura costado",
    )
    assert ReadOnlyPatternCanvas._fase44c_selection_xy(info) == (12.5, 4.0)


def test_fase44c_baseline_capture_and_reset_contract():
    class DummyCanvas:
        def __init__(self):
            self.info = {
                "piece_name": "Pieza A",
                "point_name": "Punto 1",
                "x_cm": 10.0,
                "y_cm": 20.0,
            }
            self.moves = []

        _fase44c_info_get = staticmethod(ReadOnlyPatternCanvas._fase44c_info_get)
        _fase44c_selection_key = classmethod(
            lambda cls, info: ReadOnlyPatternCanvas._fase44c_selection_key(info)
        )
        _fase44c_selection_xy = classmethod(
            lambda cls, info: ReadOnlyPatternCanvas._fase44c_selection_xy(info)
        )
        _fase44c_baselines = ReadOnlyPatternCanvas._fase44c_baselines
        capture_selected_point_baseline = ReadOnlyPatternCanvas.capture_selected_point_baseline
        reset_selected_point_to_baseline = ReadOnlyPatternCanvas.reset_selected_point_to_baseline

        def get_selected_point_info(self):
            return self.info

        def _request_keyboard_move(self, dx, dy):
            self.moves.append((dx, dy))

    canvas = DummyCanvas()

    assert canvas.capture_selected_point_baseline() is True
    canvas.info = {
        "piece_name": "Pieza A",
        "point_name": "Punto 1",
        "x_cm": 11.5,
        "y_cm": 19.0,
    }

    assert canvas.reset_selected_point_to_baseline() is True
    assert canvas.moves == [(-1.5, 1.0)]
