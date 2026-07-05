#!/usr/bin/env python3
"""Run VirinoSoftware universal GUI."""

from __future__ import annotations

import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PROJECT_ROOT))

from app.gui.universal_main_window import UniversalMainWindow


def main() -> None:
    app = UniversalMainWindow()
    app.mainloop()


if __name__ == "__main__":
    main()
