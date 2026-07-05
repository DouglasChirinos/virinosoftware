from __future__ import annotations

import argparse
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from engine.measurements.size_inference import infer_size_from_measurements
from engine.reports.size_inference_report import generate_size_inference_report


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Infiere talla nominal desde medidas")
    parser.add_argument("--waist", type=float, required=True, help="Cintura en cm")
    parser.add_argument("--hip", type=float, required=True, help="Cadera en cm")
    parser.add_argument(
        "--output",
        default="reports/inferencia_talla.md",
        help="Ruta del reporte Markdown",
    )
    return parser


def main() -> None:
    args = build_parser().parse_args()

    result = infer_size_from_measurements(waist=args.waist, hip=args.hip)
    report_path = generate_size_inference_report(
        result=result,
        output_path=PROJECT_ROOT / args.output,
    )

    print(f"WAIST: {args.waist:.2f} cm")
    print(f"HIP: {args.hip:.2f} cm")
    print(f"RECOMMENDED_SIZE: {result.recommended_size}")
    print(f"SCORE: {result.score:.2f}")
    print(f"BETWEEN_SIZES: {'YES' if result.is_between_sizes else 'NO'}")

    for diff in result.differences:
        print(
            f"DIFF_{diff.name.upper()}: user={diff.user_value:.2f} "
            f"profile={diff.profile_value:.2f} diff={diff.signed_label}"
        )

    if result.notes:
        for note in result.notes:
            print(f"NOTE: {note}")

    print(f"REPORT: {report_path}")


if __name__ == "__main__":
    main()
