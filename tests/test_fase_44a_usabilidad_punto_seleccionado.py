from app.gui.pattern_canvas import PatternCanvas
from app.gui import universal_main_window as main_window


class DummyCanvas(PatternCanvas):
    def __init__(self):
        # Evita inicializar tkinter; probamos solo contrato de datos.
        self.selected_point = None


def test_canvas_returns_empty_user_friendly_selection_info():
    canvas = DummyCanvas()

    info = canvas.get_selected_point_info()

    assert info["has_selection"] is False
    assert info["human_name"] == "Sin punto seleccionado"
    assert info["x"] is None
    assert info["y"] is None


def test_canvas_exposes_piece_point_human_name_and_coordinates():
    canvas = DummyCanvas()
    canvas.selected_point = {
        "piece_name": "Pantalon basico delantero",
        "point_id": "waist_side_end",
        "x": 26.0,
        "y": 0.0,
    }

    info = canvas.get_selected_point_info()

    assert info["has_selection"] is True
    assert info["piece_name"] == "Pantalon basico delantero"
    assert info["point_id"] == "waist_side_end"
    assert info["human_name"] == "Cintura Costado Fin"
    assert info["x"] == 26.0
    assert info["y"] == 0.0


def test_humanize_point_name_supports_existing_technical_ids():
    assert PatternCanvas.humanize_point_name("line_2_end") == "Linea 2 Fin"
    assert PatternCanvas.humanize_point_name("hip_side") == "Cadera Costado"
    assert PatternCanvas.humanize_point_name("crotch_curve_control") == "Entrepierna Curva Control"


def test_selection_summary_includes_step_and_coordinates():
    summary = main_window._fase44a_build_selection_summary(
        {
            "has_selection": True,
            "piece_name": "Short basico posterior",
            "point_id": "hip_side",
            "human_name": "Cadera Costado",
            "x": 24,
            "y": 18.5,
        },
        step_cm=0.1,
    )

    assert "Short basico posterior" in summary
    assert "Cadera Costado" in summary
    assert "hip_side" in summary
    assert "24.00 cm" in summary
    assert "18.50 cm" in summary
    assert "Paso: 0.1 cm" in summary


def test_selection_summary_handles_no_selection():
    summary = main_window._fase44a_build_selection_summary(
        {"has_selection": False},
        step_cm=1.0,
    )

    assert "Punto seleccionado: ninguno" in summary
    assert "Paso: 1.0 cm" in summary
