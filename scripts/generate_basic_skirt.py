from __future__ import annotations

import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from engine.exports.svg.writer import export_svg
from engine.garments.skirt.basic_skirt import BasicSkirtDraft
from engine.measurements.body import BodyMeasurements


def main() -> None:
    measurements = BodyMeasurements(
        waist=72.0,
        hip=98.0,
        skirt_length=60.0,
        ease=2.0,
    )
    pieces = BasicSkirtDraft(measurements).draft()
    output = export_svg(pieces, PROJECT_ROOT / "exports/svg/falda_basica_mvp.svg")
    print(f"SVG generado: {output}")


if __name__ == "__main__":
    main()
