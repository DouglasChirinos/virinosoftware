from __future__ import annotations

from pathlib import Path

from engine.generation import PatternExportRequest, PatternGenerationRequest, export_generated_pattern


def _svg_content(tmp_path: Path, garment_code: str, measurements: dict[str, float], options: dict | None = None) -> str:
    result = export_generated_pattern(
        PatternExportRequest(
            generation_request=PatternGenerationRequest(
                garment_code=garment_code,
                measurements=measurements,
                options=options or {},
            ),
            output_name=f"{garment_code}_fase_40_1",
            output_dir=tmp_path,
            export_dxf=False,
            export_pdf=False,
        )
    )
    assert result.svg_path is not None
    return result.svg_path.read_text(encoding="utf-8")


def test_falda_basica_has_real_piece_dimensions(tmp_path: Path) -> None:
    content = _svg_content(
        tmp_path,
        "falda_basica",
        {"waist": 73, "hip": 99, "skirt_length": 60, "ease": 2},
        {"full_pattern": True},
    )

    assert "Cintura: 73 cm" in content
    assert "Cintura pieza: 19.25 cm" in content
    assert "Cadera pieza: 25.75 cm" in content
    assert "Largo pieza: 60 cm" in content
    assert "Falda basica delantera" in content
    assert "Falda basica posterior" in content


def test_pantalon_basico_has_universal_dimensions_and_no_technical_points(tmp_path: Path) -> None:
    content = _svg_content(
        tmp_path,
        "pantalon_basico",
        {"waist": 84, "hip": 104, "outseam": 100, "inseam": 76},
    )

    assert "Cintura: 84 cm" in content
    assert "Cadera: 104 cm" in content
    assert "Largo exterior: 100 cm" in content
    assert "Entrepierna: 76 cm" in content
    assert "Cintura pieza:" in content
    assert "Cadera pieza:" in content
    assert "Largo exterior pieza: 100 cm" in content
    assert "line_1_start" not in content
    assert "line_1_end" not in content


def test_short_basico_has_universal_dimensions(tmp_path: Path) -> None:
    content = _svg_content(
        tmp_path,
        "short_basico",
        {"waist": 84, "hip": 104, "outseam": 45, "inseam": 20},
    )

    assert "Cintura: 84 cm" in content
    assert "Cadera: 104 cm" in content
    assert "Largo exterior: 45 cm" in content
    assert "Entrepierna: 20 cm" in content
    assert "Cintura pieza: 21 cm" in content
    assert "Cadera/pierna pieza: 26 cm" in content
    assert "Largo exterior pieza: 45 cm" in content


def test_falda_evase_has_universal_dimensions(tmp_path: Path) -> None:
    content = _svg_content(
        tmp_path,
        "falda_evase",
        {"waist": 73, "hip": 99, "skirt_length": 60, "ease": 12},
    )

    assert "Cintura: 73 cm" in content
    assert "Cadera: 99 cm" in content
    assert "Largo falda: 60 cm" in content
    assert "Cintura pieza: 18.25 cm" in content
    assert "Bajo pieza: 48.75 cm" in content
    assert "Largo falda: 60 cm" in content
