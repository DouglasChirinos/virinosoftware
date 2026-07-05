#!/usr/bin/env bash
set -Eeuo pipefail

# ==============================================================================
# VirinoSoftware - Motor de Patronaje 2D
# Fase 24: Exportacion universal SVG/DXF/PDF
#
# Objetivo:
#   Crear una capa universal de exportacion para que el generador universal
#   pueda producir SVG/DXF/PDF por codigo de prenda, sin acoplarse a falda_basica.
#
# Alcance:
#   - Crear engine/generation/exporter.py
#   - Crear PatternExportRequest / PatternExportResult
#   - Exportar piezas universales a SVG/DXF/PDF cuando sean compatibles
#   - Soportar falda_basica y pantalon_basico
#   - Crear CLI scripts/export_pattern.py
#   - Crear target make export-pattern y make export-basic-pants
#   - Mantener scripts legacy
#   - No tocar GUI
# ==============================================================================

PROJECT_DIR="/home/antares/Proyecto/motor"
FEATURE_BRANCH="feature/fase-24-exportacion-universal"
SCRIPT_PATH="scripts/64_fase_24_exportacion_universal.sh"

cd "$PROJECT_DIR"

echo "== Fase 24: Exportacion universal SVG/DXF/PDF =="
echo "== Proyecto: $PROJECT_DIR =="

echo
echo "== 1. Validando repositorio Git =="
git rev-parse --is-inside-work-tree >/dev/null

echo
echo "== 2. Estado inicial =="
git status --short
git branch --show-current
git log --oneline --decorate --max-count=10

echo
echo "== 3. Verificando arbol de trabajo =="
DIRTY_EXCLUDING_THIS_SCRIPT="$(git status --porcelain | grep -v "^?? ${SCRIPT_PATH}$" || true)"

if [[ -n "$DIRTY_EXCLUDING_THIS_SCRIPT" ]]; then
  echo
  echo "ERROR: El arbol de trabajo no esta limpio."
  echo "Cambios detectados:"
  echo "$DIRTY_EXCLUDING_THIS_SCRIPT"
  echo
  echo "Si solo son reportes regenerados por validaciones, puedes descartarlos con:"
  echo "  git restore reports/falda_basica_medidas_w73_h99_reporte.md reports/falda_basica_mvp_reporte.md"
  exit 1
fi

echo
echo "== 4. Sincronizando develop =="
git switch develop
git pull origin develop

echo
echo "== 5. Creando/cambiando a rama feature =="
if git show-ref --verify --quiet "refs/heads/$FEATURE_BRANCH"; then
  git switch "$FEATURE_BRANCH"
else
  git switch -c "$FEATURE_BRANCH"
fi

echo
echo "== 6. Validacion base antes de modificar =="
make test
make list-garments
make generate-pattern
make generate-basic-pants
make infer-size
make generate-measurement-skirt
make run-qa
make generate-all-exports
make show-reports

echo
echo "== 7. Creando exportador universal =="

cat > engine/generation/exporter.py <<'PY'
"""Universal export orchestration for generated patterns.

Fase 24 bridges the universal pattern generator with existing exporters.

The module supports two kinds of pieces:

1. Native PatternPiece objects already compatible with existing SVG/DXF/PDF
   exporters, such as ``falda_basica``.
2. Lightweight universal draft pieces, such as the MVP ``pantalon_basico``,
   which expose ``lines`` with ``start`` and ``end`` points.

When pieces are not native PatternPiece instances, the exporter normalizes them
into PatternPiece objects before delegating to the existing export stack.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Any

from engine.exports.dxf.writer import export_dxf
from engine.exports.pdf.writer import export_pdf
from engine.exports.svg.writer import export_svg
from engine.generation.pattern_generator import (
    PatternGenerationRequest,
    PatternGenerationResult,
    generate_pattern,
)
from engine.patterns.models import Line, PatternPiece, Point


class PatternExportError(Exception):
    """Raised when universal export fails."""


@dataclass(frozen=True)
class PatternExportRequest:
    """Input contract for universal pattern export."""

    generation_request: PatternGenerationRequest
    output_name: str
    export_svg: bool = True
    export_dxf: bool = True
    export_pdf: bool = True


@dataclass(frozen=True)
class PatternExportResult:
    """Output contract for universal pattern export."""

    generation_result: PatternGenerationResult
    svg_path: Path | None = None
    dxf_path: Path | None = None
    pdf_path: Path | None = None

    @property
    def exported_paths(self) -> tuple[Path, ...]:
        """Return generated export paths."""

        paths = [self.svg_path, self.dxf_path, self.pdf_path]
        return tuple(path for path in paths if path is not None)


def _read_point(raw_point: Any) -> Point:
    """Normalize an arbitrary point-like object to ``Point``."""

    if isinstance(raw_point, Point):
        return raw_point

    try:
        return Point(float(raw_point.x), float(raw_point.y))
    except AttributeError as exc:
        raise PatternExportError(f"Invalid point object: {raw_point!r}") from exc


def _read_line(raw_line: Any) -> Line:
    """Normalize an arbitrary line-like object to ``Line``."""

    if isinstance(raw_line, Line):
        return raw_line

    try:
        start = _read_point(raw_line.start)
        end = _read_point(raw_line.end)
    except AttributeError as exc:
        raise PatternExportError(f"Invalid line object: {raw_line!r}") from exc

    line_name = getattr(raw_line, "name", "")
    kind = getattr(raw_line, "kind", "pattern")

    try:
        return Line(start=start, end=end, name=line_name, kind=kind)
    except TypeError:
        return Line(start=start, end=end, name=line_name)


def _normalize_piece(raw_piece: Any) -> PatternPiece:
    """Normalize a generated piece into ``PatternPiece``."""

    if isinstance(raw_piece, PatternPiece):
        return raw_piece

    name = getattr(raw_piece, "name", None)
    raw_lines = getattr(raw_piece, "lines", None)
    metadata = getattr(raw_piece, "metadata", {})

    if not name:
        raise PatternExportError(f"Piece without name cannot be exported: {raw_piece!r}")

    if raw_lines is None:
        raise PatternExportError(f"Piece without lines cannot be exported: {name}")

    lines = [_read_line(line) for line in raw_lines]

    try:
        return PatternPiece(name=name, lines=lines, metadata=dict(metadata))
    except TypeError:
        piece = PatternPiece(name=name, lines=lines)
        if hasattr(piece, "metadata") and isinstance(piece.metadata, dict):
            piece.metadata.update(dict(metadata))
        return piece


def normalize_pieces(raw_pieces: list[Any]) -> list[PatternPiece]:
    """Normalize all generated pieces for export."""

    return [_normalize_piece(piece) for piece in raw_pieces]


def _safe_output_name(output_name: str) -> str:
    """Return a filesystem-safe output base name."""

    safe = output_name.strip().replace(" ", "_").lower()

    if not safe:
        raise PatternExportError("output_name cannot be empty")

    return safe


def export_generated_pattern(request: PatternExportRequest) -> PatternExportResult:
    """Generate and export a pattern using the universal flow."""

    generation_result = generate_pattern(request.generation_request)
    pieces = normalize_pieces(generation_result.pieces)
    output_name = _safe_output_name(request.output_name)

    svg_path: Path | None = None
    dxf_path: Path | None = None
    pdf_path: Path | None = None

    if request.export_svg:
        svg_path = Path("exports/svg") / f"{output_name}.svg"
        svg_path.parent.mkdir(parents=True, exist_ok=True)
        export_svg(pieces, svg_path)

    if request.export_dxf:
        dxf_path = Path("exports/dxf") / f"{output_name}.dxf"
        dxf_path.parent.mkdir(parents=True, exist_ok=True)
        export_dxf(pieces, dxf_path)

    if request.export_pdf:
        pdf_path = Path("exports/pdf") / f"{output_name}.pdf"
        pdf_path.parent.mkdir(parents=True, exist_ok=True)
        export_pdf(pieces, pdf_path)

    return PatternExportResult(
        generation_result=generation_result,
        svg_path=svg_path,
        dxf_path=dxf_path,
        pdf_path=pdf_path,
    )
PY

cat > engine/generation/__init__.py <<'PY'
"""Universal pattern generation package."""

from engine.generation.exporter import (
    PatternExportError,
    PatternExportRequest,
    PatternExportResult,
    export_generated_pattern,
    normalize_pieces,
)
from engine.generation.pattern_generator import (
    PatternGenerationError,
    PatternGenerationRequest,
    PatternGenerationResult,
    generate_pattern,
)

__all__ = [
    "PatternGenerationError",
    "PatternGenerationRequest",
    "PatternGenerationResult",
    "generate_pattern",
    "PatternExportError",
    "PatternExportRequest",
    "PatternExportResult",
    "export_generated_pattern",
    "normalize_pieces",
]
PY

echo
echo "== 8. Creando CLI universal de exportacion =="

cat > scripts/export_pattern.py <<'PY'
#!/usr/bin/env python3
"""Generate and export a pattern through the universal export flow."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PROJECT_ROOT))

from engine.generation import (
    PatternExportRequest,
    PatternGenerationRequest,
    export_generated_pattern,
)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Generate and export a garment pattern using the universal flow."
    )
    parser.add_argument(
        "--garment",
        default="falda_basica",
        help="Garment code registered in the garment registry.",
    )
    parser.add_argument(
        "--output",
        default=None,
        help="Output base name without extension.",
    )
    parser.add_argument("--waist", type=float, required=True, help="Waist in cm.")
    parser.add_argument("--hip", type=float, required=True, help="Hip in cm.")
    parser.add_argument(
        "--skirt-length",
        type=float,
        default=None,
        help="Skirt length in cm. Required by falda_basica.",
    )
    parser.add_argument(
        "--outseam",
        type=float,
        default=None,
        help="Outer pants length in cm. Required by pantalon_basico.",
    )
    parser.add_argument("--inseam", type=float, default=None, help="Optional inseam.")
    parser.add_argument("--rise", type=float, default=None, help="Optional rise.")
    parser.add_argument("--ease", type=float, default=None, help="Optional ease.")
    parser.add_argument("--hip-depth", type=float, default=None, help="Optional hip depth.")
    parser.add_argument("--no-svg", action="store_true", help="Skip SVG export.")
    parser.add_argument("--no-dxf", action="store_true", help="Skip DXF export.")
    parser.add_argument("--no-pdf", action="store_true", help="Skip PDF export.")
    return parser


def main() -> None:
    args = build_parser().parse_args()

    measurements = {
        "waist": args.waist,
        "hip": args.hip,
        "skirt_length": args.skirt_length,
        "outseam": args.outseam,
        "inseam": args.inseam,
        "rise": args.rise,
        "ease": args.ease,
        "hip_depth": args.hip_depth,
    }

    measurements = {
        key: value
        for key, value in measurements.items()
        if value is not None
    }

    output_name = args.output or args.garment

    result = export_generated_pattern(
        PatternExportRequest(
            generation_request=PatternGenerationRequest(
                garment_code=args.garment,
                measurements=measurements,
            ),
            output_name=output_name,
            export_svg=not args.no_svg,
            export_dxf=not args.no_dxf,
            export_pdf=not args.no_pdf,
        )
    )

    generation = result.generation_result

    print(f"GARMENT_CODE: {generation.garment_code}")
    print(f"GARMENT_NAME: {generation.garment_name}")
    print(f"DRAFT_CLASS: {generation.draft_class_name}")
    print(f"PIECE_COUNT: {generation.piece_count}")

    if result.svg_path:
        print(f"SVG: {result.svg_path.resolve()}")
    if result.dxf_path:
        print(f"DXF: {result.dxf_path.resolve()}")
    if result.pdf_path:
        print(f"PDF: {result.pdf_path.resolve()}")


if __name__ == "__main__":
    main()
PY

chmod +x scripts/export_pattern.py

echo
echo "== 9. Actualizando Makefile si aplica =="

if ! grep -q "^export-pattern:" Makefile; then
  cat >> Makefile <<'MK'

export-pattern:
	.venv/bin/python scripts/export_pattern.py --garment falda_basica --waist 73 --hip 99 --skirt-length 60 --output falda_basica_universal

export-basic-pants:
	.venv/bin/python scripts/export_pattern.py --garment pantalon_basico --waist 84 --hip 104 --outseam 100 --inseam 76 --output pantalon_basico_universal
MK
fi

echo
echo "== 10. Creando tests de exportacion universal =="

cat > tests/test_universal_pattern_exporter.py <<'PY'
"""Tests for Fase 24 universal pattern exporter."""

from __future__ import annotations

from pathlib import Path

from engine.generation import (
    PatternExportRequest,
    PatternExportResult,
    PatternGenerationRequest,
    export_generated_pattern,
    normalize_pieces,
)
from engine.patterns.models import PatternPiece


def test_normalize_pieces_keeps_pattern_piece_for_basic_skirt() -> None:
    result = export_generated_pattern(
        PatternExportRequest(
            generation_request=PatternGenerationRequest(
                garment_code="falda_basica",
                measurements={
                    "waist": 73,
                    "hip": 99,
                    "skirt_length": 60,
                },
            ),
            output_name="test_falda_basica_universal",
            export_svg=False,
            export_dxf=False,
            export_pdf=False,
        )
    )

    pieces = normalize_pieces(result.generation_result.pieces)

    assert pieces
    assert all(isinstance(piece, PatternPiece) for piece in pieces)


def test_export_generated_basic_skirt_creates_files() -> None:
    output_name = "test_falda_basica_universal"

    result = export_generated_pattern(
        PatternExportRequest(
            generation_request=PatternGenerationRequest(
                garment_code="falda_basica",
                measurements={
                    "waist": 73,
                    "hip": 99,
                    "skirt_length": 60,
                },
            ),
            output_name=output_name,
        )
    )

    assert isinstance(result, PatternExportResult)
    assert result.generation_result.garment_code == "falda_basica"

    for path in result.exported_paths:
        assert Path(path).exists()
        assert Path(path).stat().st_size > 0


def test_export_generated_basic_pants_creates_files() -> None:
    output_name = "test_pantalon_basico_universal"

    result = export_generated_pattern(
        PatternExportRequest(
            generation_request=PatternGenerationRequest(
                garment_code="pantalon_basico",
                measurements={
                    "waist": 84,
                    "hip": 104,
                    "outseam": 100,
                    "inseam": 76,
                },
            ),
            output_name=output_name,
        )
    )

    assert isinstance(result, PatternExportResult)
    assert result.generation_result.garment_code == "pantalon_basico"
    assert result.generation_result.piece_count == 2

    for path in result.exported_paths:
        assert Path(path).exists()
        assert Path(path).stat().st_size > 0


def test_export_result_exposes_only_enabled_formats() -> None:
    result = export_generated_pattern(
        PatternExportRequest(
            generation_request=PatternGenerationRequest(
                garment_code="pantalon_basico",
                measurements={
                    "waist": 84,
                    "hip": 104,
                    "outseam": 100,
                },
            ),
            output_name="test_pantalon_svg_only",
            export_svg=True,
            export_dxf=False,
            export_pdf=False,
        )
    )

    assert result.svg_path is not None
    assert result.dxf_path is None
    assert result.pdf_path is None
    assert len(result.exported_paths) == 1
PY

echo
echo "== 11. Documentando Fase 24 =="

cat > docs/33_Fase_24_Exportacion_Universal.md <<'MD'
# Fase 24 - Exportación universal SVG/DXF/PDF

## Objetivo

Crear una capa universal de exportación para que cualquier prenda generada por el generador universal pueda producir salidas SVG, DXF y PDF.

## Alcance implementado

- Se crea `engine/generation/exporter.py`.
- Se crea `PatternExportRequest`.
- Se crea `PatternExportResult`.
- Se crea `PatternExportError`.
- Se crea `export_generated_pattern`.
- Se crea `normalize_pieces`.
- Se crea CLI `scripts/export_pattern.py`.
- Se agregan targets:
  - `make export-pattern`
  - `make export-basic-pants`
- Se agregan tests de exportación universal.
- Se mantiene compatibilidad con scripts legacy.
- No se modifica el GUI.

## Flujo técnico

```text
PatternGenerationRequest
  -> generate_pattern
  -> PatternGenerationResult
  -> normalize_pieces
  -> export_svg / export_dxf / export_pdf
  -> PatternExportResult
```

## Uso

Exportar falda básica desde flujo universal:

```bash
make export-pattern
```

Exportar pantalón básico desde flujo universal:

```bash
make export-basic-pants
```

## Salidas esperadas

```text
exports/svg/falda_basica_universal.svg
exports/dxf/falda_basica_universal.dxf
exports/pdf/falda_basica_universal.pdf

exports/svg/pantalon_basico_universal.svg
exports/dxf/pantalon_basico_universal.dxf
exports/pdf/pantalon_basico_universal.pdf
```

## Decisión técnica

Fase 24 no toca el GUI. Primero estabiliza la salida universal del backend.

El GUI puede desacoplarse después para consumir:

```text
list_garments
generate_pattern
export_generated_pattern
```

## Validaciones esperadas

```bash
make test
make list-garments
make generate-pattern
make generate-basic-pants
make export-pattern
make export-basic-pants
make infer-size
make generate-measurement-skirt
make run-qa
make generate-all-exports
make show-reports
```
MD

echo
echo "== 12. Eliminando respaldos temporales si existen =="
find . -name "*.bak.*" -type f -delete

echo
echo "== 13. Validaciones finales =="
make test
make list-garments
make generate-pattern
make generate-basic-pants
make export-pattern
make export-basic-pants
make infer-size
make generate-measurement-skirt
make run-qa
make generate-all-exports
make show-reports

echo
echo "== 14. Estado final =="
git status --short
git diff --stat

echo
echo "== Fase 24 preparada =="
echo
echo "Si todo esta correcto:"
echo "  git restore reports/falda_basica_medidas_w73_h99_reporte.md reports/falda_basica_mvp_reporte.md || true"
echo "  git add engine/generation/exporter.py engine/generation/__init__.py scripts/export_pattern.py tests/test_universal_pattern_exporter.py docs/33_Fase_24_Exportacion_Universal.md Makefile ${SCRIPT_PATH}"
echo "  git commit -m \"Fase 24 exportacion universal SVG DXF PDF\""
echo "  git push -u origin $FEATURE_BRANCH"
