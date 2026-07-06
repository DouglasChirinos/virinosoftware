#!/usr/bin/env python
from __future__ import annotations

import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from engine.qa.piece_completeness import assert_complete_lower_garment


CASES = [
    (
        "falda_basica",
        {"waist": 73, "hip": 99, "skirt_length": 60, "ease": 2},
        {"full_pattern": True},
    ),
    (
        "pantalon_basico",
        {"waist": 84, "hip": 104, "outseam": 100, "inseam": 76},
        {},
    ),
    (
        "short_basico",
        {"waist": 84, "hip": 104, "outseam": 45, "inseam": 20},
        {},
    ),
    (
        "falda_evase",
        {"waist": 73, "hip": 99, "skirt_length": 60, "ease": 12},
        {},
    ),
]


def main() -> int:
    pending: list[str] = []

    for garment_code, measurements, options in CASES:
        try:
            check = assert_complete_lower_garment(
                garment_code=garment_code,
                measurements=measurements,
                options=options,
            )
        except AssertionError as exc:
            pending.append(f"{garment_code}: {exc}")
            print(f"{garment_code}: INCOMPLETE")
            print(f"  {exc}")
            continue

        print(
            f"{garment_code}: COMPLETE pieces={len(check.piece_names)} "
            f"names={', '.join(check.piece_names)}"
        )

    if pending:
        print("PIECE_COMPLETENESS_PENDING")
        return 2

    print("PIECE_COMPLETENESS_OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
