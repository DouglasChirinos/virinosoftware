#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' '== Fix Fase 37: eliminar circular import en catalog_export =='

cd /home/antares/Proyecto/motor

printf '%s\n' '== Verificando rama =='
current_branch="$(git branch --show-current)"
if [ "$current_branch" != "feature/fase-37-exportacion-masiva-catalogo-serializable" ]; then
  printf '%s\n' "ERROR: rama actual inesperada: $current_branch"
  printf '%s\n' 'Esperada: feature/fase-37-exportacion-masiva-catalogo-serializable'
  exit 1
fi

printf '%s\n' '== Aplicando fix de imports diferidos =='
python3 - <<'PY'
from pathlib import Path

path = Path("engine/garments/serializable/catalog_export.py")
if not path.exists():
    raise SystemExit("ERROR: no existe engine/garments/serializable/catalog_export.py")

text = path.read_text(encoding="utf-8")

old_import = '''from engine.generation import (
    PatternExportRequest,
    PatternGenerationRequest,
    export_generated_pattern,
)

'''
if old_import in text:
    text = text.replace(old_import, "")

old_result = '''    result = export_generated_pattern(
        PatternExportRequest(
'''
new_result = '''    # Lazy imports to avoid circular import when engine.garments imports the
    # serializable package while engine.generation is still initializing.
    from engine.generation.exporter import PatternExportRequest, export_generated_pattern
    from engine.generation.pattern_generator import PatternGenerationRequest

    result = export_generated_pattern(
        PatternExportRequest(
'''

if "from engine.generation.exporter import PatternExportRequest" not in text:
    if old_result not in text:
        raise SystemExit("ERROR: no se encontro el bloque esperado para insertar lazy import")
    text = text.replace(old_result, new_result)

path.write_text(text, encoding="utf-8")
PY

printf '%s\n' '== Registrando nota tecnica en documentacion Fase 37 =='
python3 - <<'PY'
from pathlib import Path

path = Path("docs/46_Fase_37_Exportacion_Masiva_Catalogo_Serializable.md")
if not path.exists():
    raise SystemExit("ERROR: no existe documentacion Fase 37")

text = path.read_text(encoding="utf-8")
section = '''

## Nota tecnica: imports diferidos

El modulo `engine/garments/serializable/catalog_export.py` usa imports diferidos de
`engine.generation.exporter` y `engine.generation.pattern_generator` dentro del flujo de
exportacion. Esta decision evita un ciclo de imports entre `engine.generation`,
`engine.garments` y el paquete serializable cuando se ejecutan CLIs como
`scripts/export_pattern.py`.
'''

if "## Nota tecnica: imports diferidos" not in text:
    path.write_text(text.rstrip() + section + "\n", encoding="utf-8")
PY

printf '%s\n' '== Validando fix puntual del CLI universal =='
.venv/bin/python scripts/export_pattern.py --garment short_basico --waist 84 --hip 104 --outseam 45 --inseam 20 --output short_basico_universal
.venv/bin/python scripts/export_pattern.py --garment falda_evase --waist 73 --hip 99 --skirt-length 60 --ease 12 --output falda_evase_universal

printf '%s\n' '== Validando Fase 37 completa =='
make test
make validate-garments-json
make validate-serializable-catalog
make generate-serializable-catalog
make export-serializable-catalog
make validate-geometry-short
make validate-geometry-falda-evase
make export-universal-short
make export-universal-falda-evase

printf '%s\n' '== Estado Git =='
git status --short

printf '%s\n' '== Fix Fase 37 aplicado correctamente =='
