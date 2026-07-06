from __future__ import annotations

from engine.generation import PatternExportRequest, PatternGenerationRequest, export_generated_pattern


def _export_svg_text(tmp_path, garment_code: str, measurements: dict[str, float], options: dict | None = None) -> str:
    result = export_generated_pattern(
        PatternExportRequest(
            generation_request=PatternGenerationRequest(
                garment_code=garment_code,
                measurements=measurements,
                options=options or {},
            ),
            output_name=f"{garment_code}_curves_test",
            output_dir=tmp_path / garment_code,
            export_dxf=False,
            export_pdf=False,
        )
    )

    assert result.svg_path is not None
    return result.svg_path.read_text(encoding="utf-8")


def _assert_curve_exported(content: str, old_visual_label: str, new_structural_labels: tuple[str, ...]) -> None:
    """Validate curve export across Fase 40.2 and Fase 40.3B.

    Fase 40.2 introduced dashed visual guide curves. Fase 40.3B correctly
    promotes curves to structural contour geometry with patronage semantics.
    Therefore this historical test accepts the old visual label only when the
    export has not been upgraded, and otherwise validates the structural label.
    """

    assert "<path" in content

    has_old_visual_curve = old_visual_label in content
    has_structural_curve = 'class="structural-curve"' in content
    has_expected_structural_label = any(label in content for label in new_structural_labels)

    assert has_old_visual_curve or (has_structural_curve and has_expected_structural_label)

    if has_structural_curve:
        # Fase 40.3B: structural contour curves replace dashed guide overlays.
        assert 'stroke-dasharray="6 3"' not in content


def test_falda_basica_svg_exports_hip_curve(tmp_path) -> None:
    content = _export_svg_text(
        tmp_path,
        "falda_basica",
        {"waist": 73, "hip": 99, "skirt_length": 60, "ease": 2},
        {"full_pattern": True},
    )

    _assert_curve_exported(
        content,
        old_visual_label="Curva cadera costado",
        new_structural_labels=("Costado curvo de cadera",),
    )


def test_falda_evase_svg_exports_hem_curve(tmp_path) -> None:
    content = _export_svg_text(
        tmp_path,
        "falda_evase",
        {"waist": 73, "hip": 99, "skirt_length": 60, "ease": 12},
    )

    _assert_curve_exported(
        content,
        old_visual_label="Correccion suave de bajo",
        new_structural_labels=("Bajo curvo corregido",),
    )


def test_pantalon_basico_svg_exports_mvp_rise_curve(tmp_path) -> None:
    content = _export_svg_text(
        tmp_path,
        "pantalon_basico",
        {"waist": 84, "hip": 104, "outseam": 100, "inseam": 76},
    )

    _assert_curve_exported(
        content,
        old_visual_label="Curva tiro/costado MVP",
        new_structural_labels=("Curva estructural de tiro", "Curva estructural de entrepierna"),
    )


def test_short_basico_svg_exports_mvp_rise_curve(tmp_path) -> None:
    content = _export_svg_text(
        tmp_path,
        "short_basico",
        {"waist": 84, "hip": 104, "outseam": 45, "inseam": 20},
    )

    _assert_curve_exported(
        content,
        old_visual_label="Curva tiro/entrepierna MVP",
        new_structural_labels=("Curva estructural tiro/entrepierna", "Boca de pierna curva MVP"),
    )
