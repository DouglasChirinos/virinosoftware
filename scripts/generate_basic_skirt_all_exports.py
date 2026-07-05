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
from engine.measurements.body import BodyMeasurements


def main() -> None:
    measurements = BodyMeasurements(
        waist=72.0,
        hip=98.0,
        skirt_length=60.0,
        ease=2.0,
    )

    pieces = BasicSkirtDraft(measurements).draft()

    svg_path = export_svg(pieces, PROJECT_ROOT / "exports/svg/falda_basica_mvp.svg")
    dxf_path = export_dxf(pieces, PROJECT_ROOT / "exports/dxf/falda_basica_mvp.dxf")
    pdf_path = export_pdf(pieces, PROJECT_ROOT / "exports/pdf/falda_basica_mvp.pdf")

    print(f"SVG: {svg_path}")
    print(f"DXF: {dxf_path}")
    print(f"PDF: {pdf_path}")


if __name__ == "__main__":
    main()
