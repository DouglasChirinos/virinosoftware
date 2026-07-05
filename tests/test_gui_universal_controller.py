"""Tests for Fase 25 universal GUI controller."""

from __future__ import annotations

from pathlib import Path

from app.controllers.universal_pattern_controller import (
    build_output_name,
    export_summary,
    generate_summary,
    get_default_measurements,
    get_garment_options,
    parse_measurements,
)


def test_get_garment_options_exposes_registered_garments() -> None:
    options = get_garment_options()
    codes = {option.code for option in options}

    assert "falda_basica" in codes
    assert "pantalon_basico" in codes


def test_default_measurements_for_basic_skirt() -> None:
    measurements = get_default_measurements("falda_basica")

    assert measurements["waist"] == 73.0
    assert measurements["hip"] == 99.0
    assert measurements["skirt_length"] == 60.0


def test_default_measurements_for_basic_pants() -> None:
    measurements = get_default_measurements("pantalon_basico")

    assert measurements["waist"] == 84.0
    assert measurements["hip"] == 104.0
    assert measurements["outseam"] == 100.0


def test_parse_measurements_accepts_decimal_comma() -> None:
    measurements = parse_measurements(
        {
            "waist": "73,5",
            "hip": "99.0",
            "skirt_length": "60",
            "empty": "",
        }
    )

    assert measurements["waist"] == 73.5
    assert measurements["hip"] == 99.0
    assert measurements["skirt_length"] == 60.0
    assert "empty" not in measurements


def test_generate_summary_for_basic_pants() -> None:
    summary = generate_summary(
        garment_code="pantalon_basico",
        measurements={
            "waist": 84,
            "hip": 104,
            "outseam": 100,
            "inseam": 76,
        },
    )

    assert summary.garment_code == "pantalon_basico"
    assert summary.draft_class_name == "BasicPantsDraft"
    assert summary.piece_count == 2


def test_export_summary_creates_universal_gui_exports() -> None:
    output_name = "test_gui_pantalon_basico"

    summary = export_summary(
        garment_code="pantalon_basico",
        measurements={
            "waist": 84,
            "hip": 104,
            "outseam": 100,
            "inseam": 76,
        },
        output_name=output_name,
    )

    assert summary.svg_path is not None
    assert summary.dxf_path is not None
    assert summary.pdf_path is not None

    for path in (summary.svg_path, summary.dxf_path, summary.pdf_path):
        assert Path(path).exists()
        assert Path(path).stat().st_size > 0


def test_build_output_name() -> None:
    assert build_output_name("falda_basica") == "falda_basica_gui_universal"
