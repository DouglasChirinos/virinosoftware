from __future__ import annotations

import argparse
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
from engine.measurements.size_chart import DEFAULT_SKIRT_SIZE_CHART
from engine.patterns.seam_allowance import SeamAllowanceConfig, apply_seam_allowance
from engine.qa.pattern_quality import run_pattern_quality_checks
from engine.reports.pattern_report import generate_pattern_report
from engine.reports.quality_report import generate_quality_report
from engine.reports.seam_allowance_report import generate_seam_allowance_report
from engine.reports.size_chart_report import generate_size_chart_report


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Genera falda basica por talla nominal")
    parser.add_argument("--size", default="M", help="Codigo de talla: XS, S, M, L, XL")
    parser.add_argument("--skirt-length", type=float, default=60.0, help="Largo de falda en cm")
    parser.add_argument("--ease", type=float, default=2.0, help="Holgura en cm")
    parser.add_argument("--hip-depth", type=float, default=20.0, help="Profundidad de cadera en cm")
    return parser


def main() -> None:
    configure_logging(PROJECT_ROOT)
    args = build_parser().parse_args()

    size_profile = DEFAULT_SKIRT_SIZE_CHART.get(args.size)
    measurements = size_profile.to_body_measurements(
        skirt_length=args.skirt_length,
        ease=args.ease,
        hip_depth=args.hip_depth,
    )

    base_pieces = BasicSkirtDraft(measurements).draft()
    seam_pieces = [apply_seam_allowance(piece, SeamAllowanceConfig()) for piece in base_pieces]
    pieces = base_pieces + seam_pieces

    qa_report = run_pattern_quality_checks(pieces)

    size_code = size_profile.code.lower()
    stem = f"falda_basica_talla_{size_code}"

    svg_path = export_svg(pieces, PROJECT_ROOT / f"exports/svg/{stem}.svg")
    dxf_path = export_dxf(pieces, PROJECT_ROOT / f"exports/dxf/{stem}.dxf")
    pdf_path = export_pdf(pieces, PROJECT_ROOT / f"exports/pdf/{stem}.pdf")

    pattern_report_path = generate_pattern_report(
        pieces=pieces,
        measurements=measurements,
        output_path=PROJECT_ROOT / f"reports/{stem}_reporte.md",
        title=f"Reporte tecnico - Falda basica talla {size_profile.code}",
    )

    qa_report_path = generate_quality_report(
        pieces=pieces,
        quality_report=qa_report,
        output_path=PROJECT_ROOT / f"reports/{stem}_qa.md",
        title=f"Reporte QA - Falda basica talla {size_profile.code}",
    )

    seam_report_path = generate_seam_allowance_report(
        pieces=pieces,
        output_path=PROJECT_ROOT / f"reports/{stem}_margen.md",
        title=f"Reporte margen - Falda basica talla {size_profile.code}",
    )

    size_chart_report_path = generate_size_chart_report(
        size_chart=DEFAULT_SKIRT_SIZE_CHART,
        output_path=PROJECT_ROOT / "reports/tabla_tallas_mvp.md",
    )

    print(f"SIZE: {size_profile.code}")
    print(f"SVG: {svg_path}")
    print(f"DXF: {dxf_path}")
    print(f"PDF: {pdf_path}")
    print(f"REPORT: {pattern_report_path}")
    print(f"QA_REPORT: {qa_report_path}")
    print(f"SEAM_REPORT: {seam_report_path}")
    print(f"SIZE_CHART_REPORT: {size_chart_report_path}")
    print(f"QA_STATUS: {'PASSED' if qa_report.passed else 'FAILED'}")

    if not qa_report.passed:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
