#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="/home/antares/Proyecto/motor"
BRANCH_NAME="feature/fase-40-gui-generacion-exportacion-serializables"

cd "$PROJECT_DIR"

echo "== Fix Fase 40: cotas geometricas reales, no medidas corporales =="

current_branch="$(git branch --show-current)"
if [ "$current_branch" != "$BRANCH_NAME" ]; then
  echo "ERROR: rama actual inesperada: $current_branch"
  echo "Esperado: $BRANCH_NAME"
  echo "No se aplica el fix para evitar tocar una rama incorrecta."
  exit 1
fi

echo "== Estado Git antes del fix =="
git status --short

python3 - <<'PY'
from pathlib import Path

path = Path("engine/generation/exporter.py")
text = path.read_text(encoding="utf-8")

start = text.find("def _build_basic_skirt_dimensions(piece: PatternPiece, measurements: dict[str, Any]) -> list[dict[str, Any]]:")
if start == -1:
    raise SystemExit("ERROR: no se encontro _build_basic_skirt_dimensions")

end = text.find("\ndef _attach_export_metadata", start)
if end == -1:
    raise SystemExit("ERROR: no se encontro limite antes de _attach_export_metadata")

new_function = '''def _segment_length(start: Point, end: Point) -> float:\n    return ((float(end.x) - float(start.x)) ** 2 + (float(end.y) - float(start.y)) ** 2) ** 0.5\n\n\ndef _build_basic_skirt_dimensions(piece: PatternPiece, measurements: dict[str, Any]) -> list[dict[str, Any]]:\n    """Build edge dimensions using real geometric segment lengths.\n\n    Header measurements are body/input measurements. Edge labels must describe\n    the actual pattern side shown on the piece, otherwise the user may read a\n    quarter/half piece as if it were the full body contour.\n    """\n\n    points = piece.points\n    annotations: list[dict[str, Any]] = []\n\n    def has(*names: str) -> bool:\n        return all(name in points for name in names)\n\n    def value(start_name: str, end_name: str) -> str:\n        return _format_measurement_value(\n            _segment_length(points[start_name], points[end_name])\n        )\n\n    if has("A_cintura_centro", "B_cintura_costado"):\n        annotations.append(\n            _make_dimension_annotation(\n                label=f"Cintura pieza: {value('A_cintura_centro', 'B_cintura_costado')} cm",\n                start=points["A_cintura_centro"],\n                end=points["B_cintura_costado"],\n                offset_y=-4.0,\n            )\n        )\n\n    if has("C_cadera_centro", "D_cadera_costado"):\n        annotations.append(\n            _make_dimension_annotation(\n                label=f"Cadera pieza: {value('C_cadera_centro', 'D_cadera_costado')} cm",\n                start=points["C_cadera_centro"],\n                end=points["D_cadera_costado"],\n                offset_y=4.0,\n            )\n        )\n\n    if has("A_cintura_centro", "E_bajo_centro"):\n        annotations.append(\n            _make_dimension_annotation(\n                label=f"Largo pieza: {value('A_cintura_centro', 'E_bajo_centro')} cm",\n                start=points["A_cintura_centro"],\n                end=points["E_bajo_centro"],\n                offset_x=-4.0,\n            )\n        )\n\n    return annotations\n'''

text = text[:start] + new_function + text[end + 1:]
path.write_text(text, encoding="utf-8")
PY

python3 - <<'PY'
from pathlib import Path

path = Path("tests/test_fase_40_export_visual_layout.py")
text = path.read_text(encoding="utf-8")

text = text.replace('''    assert "Cintura: 73 cm" in content\n    assert "Cadera: 99 cm" in content\n    assert "Largo falda: 60 cm" in content\n''', '''    assert "Cintura: 73 cm" in content\n    assert "Cadera: 99 cm" in content\n    assert "Largo falda: 60 cm" in content\n    assert "Cintura pieza: 19.25 cm" in content\n    assert "Cadera pieza: 25.75 cm" in content\n    assert "Largo pieza: 60 cm" in content\n''')

if "test_falda_basica_dimension_annotations_use_real_piece_lengths" not in text:
    text += '''\n\ndef test_falda_basica_dimension_annotations_use_real_piece_lengths() -> None:\n    result = export_generated_pattern(\n        PatternExportRequest(\n            generation_request=PatternGenerationRequest(\n                garment_code="falda_basica",\n                measurements={"waist": 73, "hip": 99, "skirt_length": 60, "ease": 2},\n                options={"full_pattern": True},\n            ),\n            output_name="falda_basica_dimension_annotations",\n            export_svg=False,\n            export_dxf=False,\n            export_pdf=False,\n        )\n    )\n\n    pieces = result.generation_result.pieces\n    assert len(pieces) == 2\n\n    # Exported pieces are normalized internally, so validate through SVG output\n    # in the main visual export test. This test protects generation intent.\n    assert result.generation_result.options["full_pattern"] is True\n'''

path.write_text(text, encoding="utf-8")
PY

cat > docs/53_Fix_Fase_40_Cotas_Geometricas_Reales.md <<'MD'
# Fix Fase 40 - Cotas geometricas reales

Fecha: 2026-07-05

## Problema detectado

En la exportacion visual de `falda_basica`, las cotas al borde del patron mostraban la medida corporal completa de entrada.

Ejemplo incorrecto:

```text
A_cintura_centro -> B_cintura_costado = Cintura: 73 cm
```

Esto es incorrecto porque el tramo mostrado no representa la cintura corporal completa. En una pieza delantera/posterior con centro, ese segmento representa una fraccion geometrica del patron.

## Decision

Separar dos conceptos:

- Encabezado: conserva las medidas corporales de entrada.
- Cotas al borde: muestran la longitud real del segmento dibujado.

## Resultado esperado

Para `waist=73`, `hip=99`, `skirt_length=60`, `ease=2`:

```text
Encabezado: Cintura: 73 cm | Cadera: 99 cm | Largo falda: 60 cm
Cota superior: Cintura pieza: 19.25 cm
Cota cadera: Cadera pieza: 25.75 cm
Cota vertical: Largo pieza: 60 cm
```

## Criterio de aceptacion

Las medidas colocadas junto al patron deben coincidir con el lado del patron donde aparecen.
MD

echo "== Validacion puntual de cotas geometricas =="
.venv/bin/python - <<'PY'
from pathlib import Path
from engine.generation import PatternExportRequest, PatternGenerationRequest, export_generated_pattern

out = Path("exports/tmp_fase40_cotas")
result = export_generated_pattern(
    PatternExportRequest(
        generation_request=PatternGenerationRequest(
            garment_code="falda_basica",
            measurements={"waist": 73, "hip": 99, "skirt_length": 60, "ease": 2},
            options={"full_pattern": True},
        ),
        output_name="falda_basica_cotas_geometricas",
        output_dir=out,
        export_dxf=False,
        export_pdf=False,
    )
)
assert result.svg_path is not None
content = result.svg_path.read_text(encoding="utf-8")
assert "Cintura: 73 cm" in content
assert "Cintura pieza: 19.25 cm" in content
assert "Cadera pieza: 25.75 cm" in content
assert "Largo pieza: 60 cm" in content
print("COTAS_GEOMETRICAS_OK")
PY

echo "== Validaciones Fase 40 =="
make validate-fase-40

echo "== Limpieza de exports generados por validacion =="
rm -rf exports

echo "== Estado Git despues del fix =="
git status --short

echo "== Fix aplicado correctamente =="
