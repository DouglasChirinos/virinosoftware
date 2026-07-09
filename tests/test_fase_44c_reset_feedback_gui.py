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
        _fase44c_point_ref_key = staticmethod(ReadOnlyPatternCanvas._fase44c_point_ref_key)
        _fase44c_point_ref_xy = staticmethod(ReadOnlyPatternCanvas._fase44c_point_ref_xy)
        _fase44c_current_selection_key = ReadOnlyPatternCanvas._fase44c_current_selection_key
        _fase44c_current_selection_xy = ReadOnlyPatternCanvas._fase44c_current_selection_xy
        _fase44d_selected_point_ref = ReadOnlyPatternCanvas._fase44d_selected_point_ref
        _fase44c_baselines = ReadOnlyPatternCanvas._fase44c_baselines
        capture_selected_point_baseline = ReadOnlyPatternCanvas.capture_selected_point_baseline
        reset_selected_point_to_baseline = ReadOnlyPatternCanvas.reset_selected_point_to_baseline

        def get_selected_point_info(self):
            return self.info

        def _request_keyboard_move(self, dx, dy):
            self.moves.append((dx, dy))

        def _resolve_selected_point_coordinates(self, piece_name, point_id):
            return None

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


def test_fase44c_baseline_can_use_selected_point_reference_when_info_is_partial():
    class DummyCanvas:
        def __init__(self):
            self.selected_point = {
                "piece_name": "Pieza B",
                "point_name": "Punto 2",
                "x_cm": 5.0,
                "y_cm": 8.0,
            }
            self.moves = []

        _fase44c_info_get = staticmethod(ReadOnlyPatternCanvas._fase44c_info_get)
        _fase44c_selection_key = classmethod(
            lambda cls, info: ReadOnlyPatternCanvas._fase44c_selection_key(info)
        )
        _fase44c_selection_xy = classmethod(
            lambda cls, info: ReadOnlyPatternCanvas._fase44c_selection_xy(info)
        )
        _fase44c_point_ref_key = staticmethod(ReadOnlyPatternCanvas._fase44c_point_ref_key)
        _fase44c_point_ref_xy = staticmethod(ReadOnlyPatternCanvas._fase44c_point_ref_xy)
        _fase44c_current_selection_key = ReadOnlyPatternCanvas._fase44c_current_selection_key
        _fase44c_current_selection_xy = ReadOnlyPatternCanvas._fase44c_current_selection_xy
        _fase44d_selected_point_ref = ReadOnlyPatternCanvas._fase44d_selected_point_ref
        _fase44c_baselines = ReadOnlyPatternCanvas._fase44c_baselines
        capture_selected_point_baseline = ReadOnlyPatternCanvas.capture_selected_point_baseline
        reset_selected_point_to_baseline = ReadOnlyPatternCanvas.reset_selected_point_to_baseline

        def get_selected_point_info(self):
            return {"human_name": "Punto 2"}

        def _request_keyboard_move(self, dx, dy):
            self.moves.append((dx, dy))

    canvas = DummyCanvas()
    assert canvas.capture_selected_point_baseline() is True

    canvas.selected_point = {
        "piece_name": "Pieza B",
        "point_name": "Punto 2",
        "x_cm": 6.0,
        "y_cm": 6.5,
    }

    assert canvas.reset_selected_point_to_baseline() is True
    assert canvas.moves == [(-1.0, 1.5)]

def test_fase44d_selected_point_callable_is_resolved_for_info_and_reset():
    class DummyCanvas:
        def __init__(self):
            self._point = {
                "piece_name": "Falda basica posterior",
                "point_name": "C_cadera_centro",
                "x_cm": 20.0,
                "y_cm": 30.0,
            }
            self.moves = []

        _fase44c_info_get = staticmethod(ReadOnlyPatternCanvas._fase44c_info_get)
        _fase44c_selection_key = classmethod(
            lambda cls, info: ReadOnlyPatternCanvas._fase44c_selection_key(info)
        )
        _fase44c_selection_xy = classmethod(
            lambda cls, info: ReadOnlyPatternCanvas._fase44c_selection_xy(info)
        )
        _fase44c_point_ref_key = staticmethod(ReadOnlyPatternCanvas._fase44c_point_ref_key)
        _fase44c_point_ref_xy = staticmethod(ReadOnlyPatternCanvas._fase44c_point_ref_xy)
        _fase44d_selected_point_ref = ReadOnlyPatternCanvas._fase44d_selected_point_ref
        _fase44c_current_selection_key = ReadOnlyPatternCanvas._fase44c_current_selection_key
        _fase44c_current_selection_xy = ReadOnlyPatternCanvas._fase44c_current_selection_xy
        _fase44d_selected_point_ref = ReadOnlyPatternCanvas._fase44d_selected_point_ref
        _fase44c_baselines = ReadOnlyPatternCanvas._fase44c_baselines
        capture_selected_point_baseline = ReadOnlyPatternCanvas.capture_selected_point_baseline
        reset_selected_point_to_baseline = ReadOnlyPatternCanvas.reset_selected_point_to_baseline
        get_selected_point_info = ReadOnlyPatternCanvas.get_selected_point_info

        def selected_point(self):
            return self._point

        def _request_keyboard_move(self, dx, dy):
            self.moves.append((dx, dy))

    canvas = DummyCanvas()

    info = canvas.get_selected_point_info()
    assert info["piece_name"] == "Falda basica posterior"
    assert info["point_id"] == "C_cadera_centro"
    assert info["point_name"] == "C_cadera_centro"
    assert info["has_selection"] is True
    assert "bound method" not in str(info)

    assert canvas.capture_selected_point_baseline() is True

    canvas._point = {
        "piece_name": "Falda basica posterior",
        "point_name": "C_cadera_centro",
        "x_cm": 21.0,
        "y_cm": 28.5,
    }

    assert canvas.reset_selected_point_to_baseline() is True
    assert canvas.moves == [(-1.0, 1.5)]
