from pathlib import Path
import subprocess
import sys


PROJECT_ROOT = Path(__file__).resolve().parents[1]


def test_short_basico_exports_through_universal_flow():
    output_name = "short_basico_universal"

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
            "short_basico",
            "--waist",
            "84",
            "--hip",
            "104",
            "--outseam",
            "45",
            "--inseam",
            "20",
            "--output",
            output_name,
        ],
        cwd=PROJECT_ROOT,
        check=True,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )

    assert "GARMENT_CODE: short_basico" in result.stdout
    assert "GARMENT_NAME: Short basico" in result.stdout
    assert "DRAFT_CLASS: ShortBasicoSerializableDraft" in result.stdout
    assert "PIECE_COUNT: 1" in result.stdout

    for relative_path in (
        Path("exports/svg") / f"{output_name}.svg",
        Path("exports/dxf") / f"{output_name}.dxf",
        Path("exports/pdf") / f"{output_name}.pdf",
    ):
        exported = PROJECT_ROOT / relative_path
        assert exported.exists(), f"No fue generado: {exported}"
        assert exported.stat().st_size > 0, f"Archivo vacio: {exported}"
