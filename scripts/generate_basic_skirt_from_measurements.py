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
from engine.measurements.body import BodyMeasurements
from engine.measurements.size_inference import infer_size_from_measurements
from engine.patterns.seam_allowance import SeamAllowanceConfig, apply_seam_allowance
from engine.qa.pattern_quality import run_pattern_quality_checks
from engine.reports.pattern_report import generate_pattern_report
from engine.reports.quality_report import generate_quality_report
from engine.reports.seam_allowance_report import generate_seam_allowance_report
from engine.reports.size_inference_report import generate_size_inference_report


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Genera falda basica personalizada desde medidas reales"
    )
    parser.add_argument("--waist", type=float, required=True, help="Cintura en cm")
    parser.add_argument("--hip", type=float, required=True, help="Cadera en cm")
    parser.add_argument("--skirt-length", type=float, default=60.0, help="Largo de falda en cm")
    parser.add_argument("--ease", type=float, default=2.0, help="Holgura en cm")
    parser.add_argument("--hip-depth", type=float, default=20.0, help="Profundidad de cadera en cm")
    return parser


def main() -> None:
    configure_logging(PROJECT_ROOT)
    args = build_parser().parse_args()

    measurements = BodyMeasurements(
        waist=args.waist,
        hip=args.hip,
        skirt_length=args.skirt_length,
        ease=args.ease,
        hip_depth=args.hip_depth,
        unit="cm",
    )

    inference = infer_size_from_measurements(measurements=measurements)

    base_pieces = BasicSkirtDraft(measurements).draft()
    seam_pieces = [apply_seam_allowance(piece, SeamAllowanceConfig()) for piece in base_pieces]
    pieces = base_pieces + seam_pieces

    qa_report = run_pattern_quality_checks(pieces)

    stem = f"falda_basica_medidas_w{int(args.waist)}_h{int(args.hip)}"

    svg_path = export_svg(pieces, PROJECT_ROOT / f"exports/svg/{stem}.svg")
    dxf_path = export_dxf(pieces, PROJECT_ROOT / f"exports/dxf/{stem}.dxf")
    pdf_path = export_pdf(pieces, PROJECT_ROOT / f"exports/pdf/{stem}.pdf")

    pattern_report_path = generate_pattern_report(
        pieces=pieces,
        measurements=measurements,
        output_path=PROJECT_ROOT / f"reports/{stem}_reporte.md",
        title=f"Reporte tecnico - Falda basica medidas W{args.waist:.0f} H{args.hip:.0f}",
    )

    qa_report_path = generate_quality_report(
        pieces=pieces,
        quality_report=qa_report,
        output_path=PROJECT_ROOT / f"reports/{stem}_qa.md",
        title=f"Reporte QA - Falda basica medidas W{args.waist:.0f} H{args.hip:.0f}",
    )

    seam_report_path = generate_seam_allowance_report(
        pieces=pieces,
        output_path=PROJECT_ROOT / f"reports/{stem}_margen.md",
        title=f"Reporte margen - Falda basica medidas W{args.waist:.0f} H{args.hip:.0f}",
    )

    inference_report_path = generate_size_inference_report(
        result=inference,
        output_path=PROJECT_ROOT / f"reports/{stem}_inferencia_talla.md",
    )

    print(f"WAIST: {args.waist:.2f} cm")
    print(f"HIP: {args.hip:.2f} cm")
    print(f"REFERENCE_SIZE: {inference.recommended_size}")
    print(f"BETWEEN_SIZES: {'YES' if inference.is_between_sizes else 'NO'}")
    print(f"SVG: {svg_path}")
    print(f"DXF: {dxf_path}")
    print(f"PDF: {pdf_path}")
    print(f"REPORT: {pattern_report_path}")
    print(f"QA_REPORT: {qa_report_path}")
    print(f"SEAM_REPORT: {seam_report_path}")
    print(f"SIZE_INFERENCE_REPORT: {inference_report_path}")
    print(f"QA_STATUS: {'PASSED' if qa_report.passed else 'FAILED'}")

    if not qa_report.passed:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
