from __future__ import annotations

from pathlib import Path

from engine.generation import PatternExportRequest, PatternGenerationRequest, export_generated_pattern


def _export_svg(tmp_path: Path, garment_code: str, measurements: dict[str, float], options: dict | None = None) -> str:
    result = export_generated_pattern(
        PatternExportRequest(
            generation_request=PatternGenerationRequest(
                garment_code=garment_code,
                measurements=measurements,
                options=options or {},
            ),
            output_name=f"{garment_code}_visual_metadata",
            output_dir=tmp_path,
            export_dxf=False,
            export_pdf=False,
        )
    )
    assert result.svg_path is not None
    return result.svg_path.read_text(encoding="utf-8")


def test_universal_export_svg_uses_spanish_header_measurements(tmp_path: Path) -> None:
    content = _export_svg(tmp_path, "falda_basica", {"waist": 72, "hip": 98, "skirt_length": 60}, {"full_pattern": True})

    assert "Cintura: 72 cm" in content
    assert "Cadera: 98 cm" in content
    assert "Largo falda: 60 cm" in content
    assert "waist:" not in content
    assert "skirt_length:" not in content


def test_pants_visual_export_hides_technical_generated_point_names(tmp_path: Path) -> None:
    content = _export_svg(
        tmp_path,
        "pantalon_basico",
        {"waist": 84, "hip": 104, "outseam": 100, "inseam": 76},
    )

    assert "line_1_start" not in content
    assert "line_5_end" not in content
    assert "Cintura pieza:" in content
    assert "Cadera pieza:" in content
    assert "Largo exterior pieza:" in content
