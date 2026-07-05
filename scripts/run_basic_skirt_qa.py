from __future__ import annotations

import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from engine.garments.skirt.basic_skirt import BasicSkirtDraft
from engine.measurements.body import BodyMeasurements
from engine.qa.pattern_quality import run_pattern_quality_checks
from engine.reports.quality_report import generate_quality_report


def main() -> None:
    measurements = BodyMeasurements(waist=72, hip=98, skirt_length=60)
    pieces = BasicSkirtDraft(measurements).draft()
    result = run_pattern_quality_checks(pieces)

    output = generate_quality_report(
        pieces=pieces,
        quality_report=result,
        output_path=PROJECT_ROOT / "reports/falda_basica_mvp_qa.md",
    )

    print(f"QA_REPORT: {output}")
    print(f"QA_STATUS: {'PASSED' if result.passed else 'FAILED'}")

    if not result.passed:
        for issue in result.errors:
            print(f"ERROR {issue.code}: {issue.message}")
        raise SystemExit(1)


if __name__ == "__main__":
    main()
