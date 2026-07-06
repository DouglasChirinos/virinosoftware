from pathlib import Path
import subprocess
import sys

from engine.garments.registry import get_garment, list_garments
from engine.generation import PatternGenerationRequest, generate_pattern


PROJECT_ROOT = Path(__file__).resolve().parents[1]


def test_all_json_garments_are_registered_dynamically():
    registered = {item.code: item.name for item in list_garments()}

    assert registered["short_basico"] == "Short basico"
    assert registered["falda_evase"] == "Falda evase"

    assert get_garment("short_basico").__name__ == "ShortBasicoSerializableDraft"
    assert get_garment("falda_evase").__name__ == "FaldaEvaseSerializableDraft"


def test_falda_evase_generates_from_universal_pattern_generator():
    result = generate_pattern(
        PatternGenerationRequest(
            garment_code="falda_evase",
            measurements={
                "waist": 73,
                "hip": 99,
                "skirt_length": 60,
                "ease": 12,
            },
        )
    )

    assert result.garment_code == "falda_evase"
    assert result.garment_name == "Falda evase"
    assert result.draft_class_name == "FaldaEvaseSerializableDraft"
    assert result.piece_count == 2
    assert result.pieces[0].name == "Falda evase delantera"
    assert len(result.pieces[0].lines) == 4
    assert result.pieces[0].points["C"] == (36.75, 60.0)
    assert result.pieces[0].points["D"] == (-12.0, 60.0)


def test_falda_evase_exports_through_universal_flow():
    output_name = "falda_evase_universal"

    for relative_path in (
        Path("exports/svg") / f"{output_name}.svg",
        Path("exports/dxf") / f"{output_name}.dxf",
        Path("exports/pdf") / f"{output_name}.pdf",
    ):
        path = PROJECT_ROOT / relative_path
        if path.exists():
            path.unlink()

    result = subprocess.run(
        [
            sys.executable,
            "scripts/export_pattern.py",
            "--garment",
            "falda_evase",
            "--waist",
            "73",
            "--hip",
            "99",
            "--skirt-length",
            "60",
            "--ease",
            "12",
            "--output",
            output_name,
        ],
        cwd=PROJECT_ROOT,
        check=True,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )

    assert "GARMENT_CODE: falda_evase" in result.stdout
    assert "GARMENT_NAME: Falda evase" in result.stdout
    assert "DRAFT_CLASS: FaldaEvaseSerializableDraft" in result.stdout
    assert "PIECE_COUNT: 2" in result.stdout

    for relative_path in (
        Path("exports/svg") / f"{output_name}.svg",
        Path("exports/dxf") / f"{output_name}.dxf",
        Path("exports/pdf") / f"{output_name}.pdf",
    ):
        exported = PROJECT_ROOT / relative_path
        assert exported.exists(), f"No fue generado: {exported}"
        assert exported.stat().st_size > 0, f"Archivo vacio: {exported}"
