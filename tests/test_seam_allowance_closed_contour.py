from collections import Counter
from pathlib import Path

from engine.garments.skirt.basic_skirt import BasicSkirtDraft
from engine.measurements.body import BodyMeasurements
from engine.patterns.seam_allowance import (
    SeamAllowanceConfig,
    apply_seam_allowance,
    build_closed_seam_allowance_contour,
)
from engine.qa.pattern_quality import run_pattern_quality_checks
from engine.reports.seam_allowance_report import generate_seam_allowance_report


def test_build_closed_seam_allowance_contour_returns_closed_degree_graph() -> None:
    piece = BasicSkirtDraft(BodyMeasurements(waist=72, hip=98, skirt_length=60)).build()
    margin_lines = build_closed_seam_allowance_contour(piece, SeamAllowanceConfig())

    assert len(margin_lines) >= 3

    degree: Counter[tuple[float, float]] = Counter()
    for line in margin_lines:
        degree[(round(line.start.x, 6), round(line.start.y, 6))] += 1
        degree[(round(line.end.x, 6), round(line.end.y, 6))] += 1

    assert all(count == 2 for count in degree.values())


def test_apply_seam_allowance_uses_closed_contour_mode() -> None:
    piece = BasicSkirtDraft(BodyMeasurements(waist=72, hip=98, skirt_length=60)).build()
    result = apply_seam_allowance(piece)

    assert result.metadata["seam_allowance_mode"] == "closed_contour"
    assert len(result.seam_allowance_lines) >= 3


def test_closed_seam_allowance_passes_qa() -> None:
    piece = BasicSkirtDraft(BodyMeasurements(waist=72, hip=98, skirt_length=60)).build()
    result = apply_seam_allowance(piece)

    qa = run_pattern_quality_checks([piece, result])

    assert qa.passed


def test_generate_seam_allowance_report(tmp_path: Path) -> None:
    piece = BasicSkirtDraft(BodyMeasurements(waist=72, hip=98, skirt_length=60)).build()
    result = apply_seam_allowance(piece)

    output = generate_seam_allowance_report(
        pieces=[piece, result],
        output_path=tmp_path / "margen.md",
    )

    assert output.exists()
    text = output.read_text(encoding="utf-8")
    assert "contorno cerrado" in text.lower()
    assert "Lineas de margen" in text
