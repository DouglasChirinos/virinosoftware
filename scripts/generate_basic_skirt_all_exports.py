from __future__ import annotations

import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from engine.exports.dxf.writer import export_dxf
from engine.exports.pdf.writer import export_pdf
from engine.exports.svg.writer import export_svg
from engine.garments.skirt.basic_skirt import BasicSkirtDraft
from engine.logging.config import configure_logging
from engine.measurements.body import BodyMeasurements
from engine.qa.pattern_quality import run_pattern_quality_checks
from engine.reports.pattern_report import generate_pattern_report
from engine.reports.quality_report import generate_quality_report


def main() -> None:
    configure_logging(PROJECT_ROOT)

    measurements = BodyMeasurements(
        waist=72.0,
        hip=98.0,
        skirt_length=60.0,
        ease=2.0,
    )

    pieces = BasicSkirtDraft(measurements).draft()
    qa_report = run_pattern_quality_checks(pieces)

    svg_path = export_svg(pieces, PROJECT_ROOT / "exports/svg/falda_basica_mvp.svg")
    dxf_path = export_dxf(pieces, PROJECT_ROOT / "exports/dxf/falda_basica_mvp.dxf")
    pdf_path = export_pdf(pieces, PROJECT_ROOT / "exports/pdf/falda_basica_mvp.pdf")

    pattern_report_path = generate_pattern_report(
        pieces=pieces,
        measurements=measurements,
        output_path=PROJECT_ROOT / "reports/falda_basica_mvp_reporte.md",
    )

    qa_report_path = generate_quality_report(
        pieces=pieces,
        quality_report=qa_report,
        output_path=PROJECT_ROOT / "reports/falda_basica_mvp_qa.md",
    )

    print(f"SVG: {svg_path}")
    print(f"DXF: {dxf_path}")
    print(f"PDF: {pdf_path}")
    print(f"REPORT: {pattern_report_path}")
    print(f"QA_REPORT: {qa_report_path}")
    print(f"QA_STATUS: {'PASSED' if qa_report.passed else 'FAILED'}")

    if not qa_report.passed:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
