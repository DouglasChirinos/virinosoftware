#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="/home/antares/Proyecto/motor"
PHASE_BRANCH="feature/fase-33-validacion-visual-geometrica-serializables"
PLAYBOOK_NAME="83_fase_33_validacion_visual_geometrica_serializables.sh"

cd "$PROJECT_ROOT"

echo "== Fase 33: Validacion visual/geometrica de prendas serializables =="
echo "== Verificando rama =="
current_branch="$(git branch --show-current)"
if [ "$current_branch" != "$PHASE_BRANCH" ]; then
  echo "ERROR: rama actual '$current_branch'. Debe ser '$PHASE_BRANCH'."
  exit 1
fi

echo "== Verificando estado Git limpio, tolerando solo este playbook sin rastrear =="
status="$(git status --short)"
allowed="?? scripts/$PLAYBOOK_NAME"
if [ -n "$status" ] && [ "$status" != "$allowed" ]; then
  echo "ERROR: el arbol de trabajo no esta limpio antes de iniciar Fase 33."
  git status --short
  exit 1
fi

echo "== Validando base Fase 32 =="
make test
make generate-universal-falda-evase
make export-universal-falda-evase
make generate-universal-short
make export-universal-short

mkdir -p engine/validation tests docs scripts

echo "== Creando modulo de validacion geometrica =="
cat > engine/validation/pattern_geometry.py <<'PY'
"""Geometry quality checks for generated pattern pieces and exported files."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable


class PatternGeometryValidationError(ValueError):
    """Raised when generated pattern geometry is structurally invalid."""


@dataclass(frozen=True)
class BoundingBox:
    """Axis-aligned bounding box in pattern units."""

    min_x: float
    min_y: float
    max_x: float
    max_y: float

    @property
    def width(self) -> float:
        return self.max_x - self.min_x

    @property
    def height(self) -> float:
        return self.max_y - self.min_y

    @property
    def area(self) -> float:
        return self.width * self.height


@dataclass(frozen=True)
class PieceGeometryReport:
    """Computed geometry report for one generated piece."""

    name: str
    line_count: int
    point_count: int
    bounding_box: BoundingBox

    @property
    def width(self) -> float:
        return self.bounding_box.width

    @property
    def height(self) -> float:
        return self.bounding_box.height


@dataclass(frozen=True)
class PatternGeometryReport:
    """Computed geometry report for a full generated pattern."""

    garment_code: str
    piece_reports: tuple[PieceGeometryReport, ...]

    @property
    def piece_count(self) -> int:
        return len(self.piece_reports)


def _point_xy(point: Any) -> tuple[float, float]:
    if hasattr(point, "x") and hasattr(point, "y"):
        return (float(point.x), float(point.y))

    if isinstance(point, (tuple, list)) and len(point) >= 2:
        return (float(point[0]), float(point[1]))

    if isinstance(point, dict):
        if "x" in point and "y" in point:
            return (float(point["x"]), float(point["y"]))
        if 0 in point and 1 in point:
            return (float(point[0]), float(point[1]))

    raise PatternGeometryValidationError(f"Invalid point object: {point!r}")


def _line_endpoints(piece: Any, line: Any) -> tuple[tuple[float, float], tuple[float, float]]:
    if hasattr(line, "start") and hasattr(line, "end"):
        return (_point_xy(line.start), _point_xy(line.end))

    if isinstance(line, (tuple, list)) and len(line) == 2:
        start_key, end_key = line
    elif isinstance(line, dict) and "start" in line and "end" in line:
        start_key, end_key = line["start"], line["end"]
    else:
        raise PatternGeometryValidationError(f"Invalid line object: {line!r}")

    points = getattr(piece, "points", None)
    if not isinstance(points, dict):
        raise PatternGeometryValidationError(
            f"Line reference requires piece.points dict: {line!r}"
        )

    try:
        start = points[start_key]
        end = points[end_key]
    except KeyError as exc:
        raise PatternGeometryValidationError(
            f"Line references unknown point {exc.args[0]!r}: {line!r}"
        ) from exc

    return (_point_xy(start), _point_xy(end))


def _collect_piece_points(piece: Any) -> list[tuple[float, float]]:
    if not hasattr(piece, "lines"):
        raise PatternGeometryValidationError(f"Piece without lines: {piece!r}")

    coordinates: list[tuple[float, float]] = []
    for line in piece.lines:
        start, end = _line_endpoints(piece, line)
        coordinates.extend([start, end])

    return coordinates


def compute_piece_geometry_report(piece: Any) -> PieceGeometryReport:
    """Return geometry report for one generated piece."""

    name = getattr(piece, "name", "")
    if not name:
        raise PatternGeometryValidationError(f"Piece without name: {piece!r}")

    coordinates = _collect_piece_points(piece)
    if not coordinates:
        raise PatternGeometryValidationError(f"Piece without drawable coordinates: {piece!r}")

    xs = [point[0] for point in coordinates]
    ys = [point[1] for point in coordinates]
    bbox = BoundingBox(min(xs), min(ys), max(xs), max(ys))

    if bbox.width <= 0:
        raise PatternGeometryValidationError(
            f"Piece {name!r} has non-positive width: {bbox.width}"
        )
    if bbox.height <= 0:
        raise PatternGeometryValidationError(
            f"Piece {name!r} has non-positive height: {bbox.height}"
        )
    if bbox.area <= 0:
        raise PatternGeometryValidationError(
            f"Piece {name!r} has non-positive area: {bbox.area}"
        )

    unique_points = set(coordinates)
    return PieceGeometryReport(
        name=name,
        line_count=len(piece.lines),
        point_count=len(unique_points),
        bounding_box=bbox,
    )


def compute_pattern_geometry_report(
    *, garment_code: str, pieces: Iterable[Any]
) -> PatternGeometryReport:
    """Return geometry report for all generated pieces."""

    reports = tuple(compute_piece_geometry_report(piece) for piece in pieces)
    if not reports:
        raise PatternGeometryValidationError(
            f"Garment {garment_code!r} generated no pieces"
        )

    return PatternGeometryReport(garment_code=garment_code, piece_reports=reports)


def validate_exported_files(paths: Iterable[Path], *, min_bytes: int = 100) -> tuple[Path, ...]:
    """Validate that exported files exist and are not empty/trivial."""

    validated: list[Path] = []
    for path in paths:
        if not path.exists():
            raise PatternGeometryValidationError(f"Exported file does not exist: {path}")
        if not path.is_file():
            raise PatternGeometryValidationError(f"Exported path is not a file: {path}")
        size = path.stat().st_size
        if size < min_bytes:
            raise PatternGeometryValidationError(
                f"Exported file is too small: {path} ({size} bytes)"
            )
        validated.append(path)

    return tuple(validated)
PY

cat > engine/validation/__init__.py <<'PY'
"""Validation helpers for generated pattern geometry and exports."""

from engine.validation.pattern_geometry import (
    BoundingBox,
    PatternGeometryReport,
    PatternGeometryValidationError,
    PieceGeometryReport,
    compute_pattern_geometry_report,
    compute_piece_geometry_report,
    validate_exported_files,
)

__all__ = [
    "BoundingBox",
    "PatternGeometryReport",
    "PatternGeometryValidationError",
    "PieceGeometryReport",
    "compute_pattern_geometry_report",
    "compute_piece_geometry_report",
    "validate_exported_files",
]
PY

echo "== Creando script CLI de validacion serializable =="
cat > scripts/validate_serializable_geometry.py <<'PY'
#!/usr/bin/env python3
"""Validate generated geometry and exports for serializable garments."""

from __future__ import annotations

import argparse
from pathlib import Path
from typing import Any

from engine.generation import PatternExportRequest, PatternGenerationRequest, export_generated_pattern
from engine.validation import compute_pattern_geometry_report, validate_exported_files


def _parse_measurements(values: list[str]) -> dict[str, float]:
    measurements: dict[str, float] = {}
    for value in values:
        if "=" not in value:
            raise SystemExit(f"Invalid measurement {value!r}; expected key=value")
        key, raw = value.split("=", 1)
        key = key.strip().replace("-", "_")
        if not key:
            raise SystemExit(f"Invalid empty measurement name in {value!r}")
        measurements[key] = float(raw)
    return measurements


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Validate serializable garment geometry and exported files."
    )
    parser.add_argument("--garment", required=True, help="Garment code to validate")
    parser.add_argument(
        "--measurement",
        action="append",
        default=[],
        help="Measurement as key=value. Can be repeated.",
    )
    parser.add_argument(
        "--output",
        default=None,
        help="Output name for exported files. Defaults to <garment>_geometry_validation.",
    )
    parser.add_argument(
        "--min-export-bytes",
        type=int,
        default=100,
        help="Minimum byte size for each exported file.",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    measurements = _parse_measurements(args.measurement)
    output_name = args.output or f"{args.garment}_geometry_validation"

    result = export_generated_pattern(
        PatternExportRequest(
            generation_request=PatternGenerationRequest(
                garment_code=args.garment,
                measurements=measurements,
            ),
            output_name=output_name,
        )
    )

    geometry_report = compute_pattern_geometry_report(
        garment_code=args.garment,
        pieces=result.generation_result.pieces,
    )
    exported_paths = validate_exported_files(
        result.exported_paths,
        min_bytes=args.min_export_bytes,
    )

    print(f"GARMENT_CODE: {geometry_report.garment_code}")
    print(f"PIECE_COUNT: {geometry_report.piece_count}")
    for index, piece_report in enumerate(geometry_report.piece_reports, start=1):
        bbox = piece_report.bounding_box
        print(
            "PIECE_{index}: {name} lines={lines} points={points} "
            "bbox=({min_x:.2f},{min_y:.2f})-({max_x:.2f},{max_y:.2f}) "
            "width={width:.2f} height={height:.2f}".format(
                index=index,
                name=piece_report.name,
                lines=piece_report.line_count,
                points=piece_report.point_count,
                min_x=bbox.min_x,
                min_y=bbox.min_y,
                max_x=bbox.max_x,
                max_y=bbox.max_y,
                width=piece_report.width,
                height=piece_report.height,
            )
        )

    for path in exported_paths:
        print(f"EXPORT_OK: {path} bytes={path.stat().st_size}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
PY
chmod +x scripts/validate_serializable_geometry.py

echo "== Agregando targets Makefile Fase 33 =="
python3 - <<'PY'
from pathlib import Path

path = Path("Makefile")
text = path.read_text(encoding="utf-8")
block = """
validate-geometry-short:
	.venv/bin/python scripts/validate_serializable_geometry.py --garment short_basico --measurement waist=84 --measurement hip=104 --measurement outseam=45 --measurement inseam=20 --output short_basico_geometry_validation

validate-geometry-falda-evase:
	.venv/bin/python scripts/validate_serializable_geometry.py --garment falda_evase --measurement waist=73 --measurement hip=99 --measurement skirt_length=60 --measurement ease=12 --output falda_evase_geometry_validation
"""

if "validate-geometry-short:" not in text:
    if not text.endswith("\n"):
        text += "\n"
    text += block

path.write_text(text, encoding="utf-8")
PY

echo "== Creando pruebas Fase 33 =="
cat > tests/test_serializable_geometry_validation.py <<'PY'
from pathlib import Path
from types import SimpleNamespace

import pytest

from engine.generation import PatternExportRequest, PatternGenerationRequest, export_generated_pattern
from engine.validation import (
    PatternGeometryValidationError,
    compute_pattern_geometry_report,
    compute_piece_geometry_report,
    validate_exported_files,
)

PROJECT_ROOT = Path(__file__).resolve().parents[1]


def test_short_basico_geometry_report_has_positive_bbox() -> None:
    result = export_generated_pattern(
        PatternExportRequest(
            generation_request=PatternGenerationRequest(
                garment_code="short_basico",
                measurements={
                    "waist": 84,
                    "hip": 104,
                    "outseam": 45,
                    "inseam": 20,
                },
            ),
            output_name="test_short_geometry_validation",
            export_svg=False,
            export_dxf=False,
            export_pdf=False,
        )
    )

    report = compute_pattern_geometry_report(
        garment_code="short_basico",
        pieces=result.generation_result.pieces,
    )

    assert report.piece_count == 1
    piece = report.piece_reports[0]
    assert piece.line_count == 4
    assert piece.point_count == 4
    assert piece.width == pytest.approx(26.0)
    assert piece.height == pytest.approx(45.0)


def test_falda_evase_geometry_report_has_expected_expanded_bbox() -> None:
    result = export_generated_pattern(
        PatternExportRequest(
            generation_request=PatternGenerationRequest(
                garment_code="falda_evase",
                measurements={
                    "waist": 73,
                    "hip": 99,
                    "skirt_length": 60,
                    "ease": 12,
                },
            ),
            output_name="test_falda_evase_geometry_validation",
            export_svg=False,
            export_dxf=False,
            export_pdf=False,
        )
    )

    report = compute_pattern_geometry_report(
        garment_code="falda_evase",
        pieces=result.generation_result.pieces,
    )

    assert report.piece_count == 1
    piece = report.piece_reports[0]
    assert piece.line_count == 4
    assert piece.point_count == 4
    assert piece.width == pytest.approx(36.75)
    assert piece.height == pytest.approx(60.0)


def test_geometry_validation_rejects_flat_piece() -> None:
    point_a = SimpleNamespace(x=0.0, y=0.0)
    point_b = SimpleNamespace(x=10.0, y=0.0)
    line = SimpleNamespace(start=point_a, end=point_b)
    piece = SimpleNamespace(name="Pieza plana", lines=[line])

    with pytest.raises(PatternGeometryValidationError):
        compute_piece_geometry_report(piece)


def test_validate_exported_files_rejects_missing_file() -> None:
    missing = PROJECT_ROOT / "exports" / "svg" / "no_existe_fase_33.svg"

    with pytest.raises(PatternGeometryValidationError):
        validate_exported_files([missing])


def test_falda_evase_exported_files_are_non_trivial() -> None:
    output_name = "test_falda_evase_geometry_exports"
    result = export_generated_pattern(
        PatternExportRequest(
            generation_request=PatternGenerationRequest(
                garment_code="falda_evase",
                measurements={
                    "waist": 73,
                    "hip": 99,
                    "skirt_length": 60,
                    "ease": 12,
                },
            ),
            output_name=output_name,
        )
    )

    validated = validate_exported_files(result.exported_paths, min_bytes=100)

    assert len(validated) == 3
    assert {path.suffix for path in validated} == {".svg", ".dxf", ".pdf"}
PY

echo "== Documentando Fase 33 =="
cat > docs/42_Fase_33_Validacion_Visual_Geometrica_Serializables.md <<'MD'
# Fase 33 - Validacion visual/geometrica de prendas serializables

## Objetivo

Agregar una capa objetiva de control de calidad geometrico para prendas serializables antes de seguir ampliando el catalogo JSON.

La fase no cambia el motor de patronaje ni agrega prendas nuevas. Su foco es validar que los patrones generados tengan geometria minima coherente y que los archivos exportados no esten vacios.

## Alcance

- Calculo de bounding box por pieza.
- Validacion de ancho, alto y area positivos.
- Soporte para lineas clasicas y lineas serializables por referencia.
- Soporte para puntos como objetos, tuplas, listas o diccionarios.
- Validacion de archivos SVG/DXF/PDF existentes y con tamano minimo.
- CLI de validacion para prendas serializables.
- Targets Makefile para validar `short_basico` y `falda_evase`.

## Archivos agregados

```text
engine/validation/__init__.py
engine/validation/pattern_geometry.py
scripts/validate_serializable_geometry.py
tests/test_serializable_geometry_validation.py
docs/42_Fase_33_Validacion_Visual_Geometrica_Serializables.md
scripts/83_fase_33_validacion_visual_geometrica_serializables.sh
```

## Targets agregados

```bash
make validate-geometry-short
make validate-geometry-falda-evase
```

## Resultado esperado

```text
short_basico  -> bbox positivo, 4 puntos, 4 lineas, exports no triviales
falda_evase   -> bbox positivo, 4 puntos, 4 lineas, exports no triviales
```

## Criterios de aceptacion

```bash
make test
make validate-geometry-short
make validate-geometry-falda-evase
make export-universal-short
make export-universal-falda-evase
```

## Nota tecnica

Esta fase prepara el camino para controles visuales mas estrictos en fases posteriores, por ejemplo snapshots SVG, tolerancias por tipo de prenda o validacion de proporciones antropometricas.
MD

echo "== Validando sintaxis =="
.venv/bin/python -m compileall engine/validation scripts/validate_serializable_geometry.py

echo "== Ejecutando validaciones completas Fase 33 =="
make test
make validate-geometry-short
make validate-geometry-falda-evase
make export-universal-short
make export-universal-falda-evase

echo "== Estado Git =="
git status --short

echo "OK: Fase 33 aplicada y validada."
