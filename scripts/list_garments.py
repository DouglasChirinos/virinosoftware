#!/usr/bin/env python3
"""List garments registered in the dynamic garment registry."""

from __future__ import annotations

import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PROJECT_ROOT))

from engine.garments import list_garments


def main() -> None:
    garments = list_garments()

    if not garments:
        print("NO_GARMENTS_REGISTERED")
        return

    for garment in garments:
        print(f"{garment.code}: {garment.name}")


if __name__ == "__main__":
    main()
