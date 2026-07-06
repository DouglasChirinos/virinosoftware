#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="/home/antares/Proyecto/motor"
BRANCH_NAME="feature/fase-40-gui-generacion-exportacion-serializables"

cd "$PROJECT_DIR"

echo "== Fix Fase 40.1A: import path para validate_piece_completeness =="

current_branch="$(git branch --show-current)"
if [ "$current_branch" != "$BRANCH_NAME" ]; then
  echo "ERROR: rama actual inesperada: $current_branch"
  echo "Esperado: $BRANCH_NAME"
  exit 1
fi

echo "== Estado Git antes del fix =="
git status --short

cat > scripts/validate_piece_completeness.py <<'PY'
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
PY

chmod +x scripts/validate_piece_completeness.py

echo "== Validacion import path =="
.venv/bin/python scripts/validate_piece_completeness.py || true

echo "== Tests Fase 40.1A =="
.venv/bin/python -m pytest tests/test_fase_40_1a_piece_completeness.py -q

echo "== Estado Git despues del fix =="
git status --short

echo "== Fix aplicado =="
