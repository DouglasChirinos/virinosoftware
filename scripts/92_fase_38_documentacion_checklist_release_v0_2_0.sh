#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="/home/antares/Proyecto/motor"
EXPECTED_BRANCH="feature/fase-38-documentacion-checklist-release-v0-2-0"

cd "$PROJECT_DIR"

echo "== Fase 38: Documentacion y checklist release v0.2.0 =="

echo "== Verificando rama =="
CURRENT_BRANCH="$(git branch --show-current)"
if [ "$CURRENT_BRANCH" != "$EXPECTED_BRANCH" ]; then
  echo "ERROR: rama actual '$CURRENT_BRANCH'. Se esperaba '$EXPECTED_BRANCH'."
  echo "Crea/cambia a la rama correcta antes de ejecutar este playbook."
  exit 1
fi

echo "== Verificando estado Git base =="
if [ -n "$(git status --short)" ]; then
  echo "ERROR: el arbol de trabajo no esta limpio."
  git status --short
  exit 1
fi

echo "== Validando base tecnica antes de documentar =="
make test
make validate-garments-json
make validate-serializable-catalog
make generate-serializable-catalog
make export-serializable-catalog
make validate-geometry-short
make validate-geometry-falda-evase
make export-universal-short
make export-universal-falda-evase

rm -rf exports

echo "== Creando documentacion de release v0.2.0 =="
mkdir -p docs

cat > docs/47_Fase_38_Documentacion_Checklist_Release_v0_2_0.md <<'DOC'
# Fase 38 - Documentacion y checklist release v0.2.0

## Objetivo

Cerrar la documentacion tecnica y operativa previa al release `v0.2.0` del motor de patronaje 2D.

Esta fase no agrega codigo funcional nuevo. Su alcance es consolidar:

- alcance del release,
- comandos reproducibles,
- checklist de validacion,
- criterios de aceptacion,
- estado de ramas,
- pendientes para la siguiente iteracion.

## Estado del release candidato

Release candidato:

```text
v0.2.0 - Motor serializable JSON MVP
```

Rama fuente del release:

```text
develop
```

Rama de produccion destino en la siguiente fase:

```text
main
```

## Capacidades incluidas

El release `v0.2.0` consolida el ciclo serializable del motor:

1. Definicion de prendas por JSON.
2. Interpretacion de formulas geometricas.
3. Registro dinamico de prendas serializables en el catalogo universal.
4. Generacion universal de patrones desde prendas JSON.
5. Exportacion universal SVG/DXF/PDF.
6. Validacion geometrica de patrones generados.
7. Validacion semantica del DSL JSON.
8. Validacion masiva del catalogo serializable.
9. Generacion masiva del catalogo serializable.
10. Exportacion masiva SVG/DXF/PDF del catalogo serializable.

## Prendas serializables incluidas

```text
examples/garments/short_basico.json
examples/garments/falda_evase.json
```

## Comandos principales del release

### Listar prendas

```bash
make list-garments
```

### Validar definiciones JSON

```bash
make validate-garments-json
```

### Validar catalogo serializable

```bash
make validate-serializable-catalog
```

### Generar catalogo serializable

```bash
make generate-serializable-catalog
```

### Exportar catalogo serializable SVG/DXF/PDF

```bash
make export-serializable-catalog
```

### Validar geometria de prendas serializables conocidas

```bash
make validate-geometry-short
make validate-geometry-falda-evase
```

### Exportar prendas individuales por flujo universal

```bash
make export-universal-short
make export-universal-falda-evase
```

## Checklist tecnico de release

Antes de promover a `main`, ejecutar desde `develop`:

```bash
cd /home/antares/Proyecto/motor

git switch develop
git pull origin develop
git status --short
git log --oneline --decorate --max-count=10

make test
make validate-garments-json
make validate-serializable-catalog
make generate-serializable-catalog
make export-serializable-catalog
make validate-geometry-short
make validate-geometry-falda-evase
make export-universal-short
make export-universal-falda-evase

rm -rf exports
git status --short
```

Resultado esperado:

```text
141 passed, 7 warnings
VALID_DEFINITION para short_basico y falda_evase
CATALOG_OK definitions=2
CATALOG_GENERATION_OK definitions=2
CATALOG_EXPORT_OK definitions=2 exported_files=6
validate-geometry-short OK
validate-geometry-falda-evase OK
export-universal-short OK
export-universal-falda-evase OK
git status --short sin salida despues de eliminar exports
```

## Criterios de aceptacion

El release es aceptable si:

- `make test` pasa completo.
- Las definiciones JSON del catalogo pasan validacion semantica.
- El catalogo serializable genera geometria sin errores.
- El catalogo serializable exporta SVG/DXF/PDF.
- Las exportaciones individuales existentes siguen funcionando.
- No quedan archivos generados en Git, especialmente `exports/`.
- `develop` queda limpio y actualizado en `origin/develop`.
- La siguiente fase puede promover `develop` a `main` sin introducir codigo adicional.

## Advertencias conocidas

Durante las pruebas aparecen warnings de `ezdxf`/`pyparsing`:

```text
PyparsingDeprecationWarning
```

No son fallos funcionales del proyecto y no bloquean el release.

## Fuera de alcance de v0.2.0

No se incluye todavia:

- GUI para gestion de prendas serializables JSON.
- Editor visual de DSL.
- Gradacion industrial completa.
- Piquetes, aplomos, costuras industriales avanzadas por DSL.
- Curvas complejas o splines en JSON.
- Exportacion por lotes empaquetada en ZIP.
- Instalador o paquete distribuible.

## Siguiente fase

```text
Fase 39 - Release v0.2.0: merge develop -> main + tag
```

Alcance de Fase 39:

- validar `develop`,
- cambiar a `main`,
- actualizar `main` desde remoto,
- mergear `develop` hacia `main`,
- ejecutar validaciones finales,
- crear tag `v0.2.0`,
- empujar `main` y tag a GitHub.
DOC

cat > docs/48_Checklist_Release_v0_2_0.md <<'DOC'
# Checklist Release v0.2.0

## Identificacion

```text
Proyecto: VirinoSoftware - Motor de Patronaje 2D
Release: v0.2.0
Tipo: MVP tecnico serializable JSON
Rama candidata: develop
Rama produccion: main
```

## Checklist pre-release

- [ ] Estar en `develop`.
- [ ] `git pull origin develop` ejecutado.
- [ ] `git status --short` sin salida antes de validar.
- [ ] `make test` aprobado.
- [ ] `make validate-garments-json` aprobado.
- [ ] `make validate-serializable-catalog` aprobado.
- [ ] `make generate-serializable-catalog` aprobado.
- [ ] `make export-serializable-catalog` aprobado.
- [ ] `make validate-geometry-short` aprobado.
- [ ] `make validate-geometry-falda-evase` aprobado.
- [ ] `make export-universal-short` aprobado.
- [ ] `make export-universal-falda-evase` aprobado.
- [ ] `exports/` eliminado antes de commit/tag.
- [ ] `git status --short` sin salida despues de limpiar exports.

## Checklist release Git

- [ ] Cambiar a `main`.
- [ ] Actualizar `main` desde remoto.
- [ ] Mergear `develop` hacia `main` con `--no-ff`.
- [ ] Ejecutar validaciones finales en `main`.
- [ ] Eliminar `exports/`.
- [ ] Confirmar `git status --short` limpio.
- [ ] Crear tag anotado `v0.2.0`.
- [ ] Push de `main`.
- [ ] Push del tag `v0.2.0`.

## Comandos de validacion

```bash
make test
make validate-garments-json
make validate-serializable-catalog
make generate-serializable-catalog
make export-serializable-catalog
make validate-geometry-short
make validate-geometry-falda-evase
make export-universal-short
make export-universal-falda-evase
rm -rf exports
git status --short
```

## Resultado esperado

```text
141 passed, 7 warnings
CATALOG_OK definitions=2
CATALOG_GENERATION_OK definitions=2
CATALOG_EXPORT_OK definitions=2 exported_files=6
git status --short sin salida
```
DOC

cat > docs/49_Release_Notes_v0_2_0.md <<'DOC'
# Release Notes - v0.2.0

## Resumen ejecutivo

`v0.2.0` convierte el motor de patronaje 2D en un MVP tecnico basado en prendas serializables JSON.

El valor principal del release es que una prenda puede describirse mediante un contrato JSON, validarse, generar geometria y exportarse a SVG/DXF/PDF usando el flujo universal.

## Nuevas capacidades desde v0.1.0

- Contrato serializable de prendas.
- Motor de interpretacion de formulas geometricas.
- Adaptador de prenda serializable al generador universal.
- Registro de prendas serializables en catalogo universal.
- Exportacion universal de prendas serializables.
- Nueva prenda `falda_evase` definida por JSON.
- Validacion geometrica de patrones serializables.
- Validacion semantica del DSL JSON.
- Validacion masiva del catalogo JSON.
- Generacion masiva del catalogo JSON.
- Exportacion masiva SVG/DXF/PDF del catalogo JSON.

## Prendas incluidas

```text
short_basico
falda_evase
```

## Comandos clave

```bash
make validate-garments-json
make validate-serializable-catalog
make generate-serializable-catalog
make export-serializable-catalog
```

## Estado de calidad esperado

```text
141 passed, 7 warnings
```

Los warnings conocidos provienen de dependencias externas `ezdxf`/`pyparsing` y no bloquean la entrega.

## Limitaciones conocidas

- El DSL actual cubre geometria lineal basica.
- No hay editor visual de prendas JSON.
- No hay empaquetado ZIP de exports.
- El catalogo serializable contiene dos prendas de referencia.
- Las salidas generadas en `exports/` no se versionan.

## Siguiente objetivo posterior al release

Despues de `v0.2.0`, el siguiente bloque estrategico deberia enfocarse en:

- ampliar DSL industrial,
- agregar nuevas prendas,
- mejorar expresividad geometrica,
- preparar empaquetado/distribucion,
- evaluar integracion GUI para prendas serializables.
DOC

cat > docs/50_Runbook_Release_v0_2_0.md <<'DOC'
# Runbook Release v0.2.0

Este runbook se ejecuta en Fase 39. Se documenta aqui para que el release sea reproducible.

## 1. Validar develop

```bash
cd /home/antares/Proyecto/motor

git switch develop
git pull origin develop
git status --short

make test
make validate-garments-json
make validate-serializable-catalog
make generate-serializable-catalog
make export-serializable-catalog
make validate-geometry-short
make validate-geometry-falda-evase
make export-universal-short
make export-universal-falda-evase

rm -rf exports
git status --short
```

## 2. Promover a main

```bash
git switch main
git pull origin main
git merge --no-ff develop -m "Release v0.2.0 motor serializable JSON"
```

## 3. Validar main

```bash
make test
make validate-garments-json
make validate-serializable-catalog
make generate-serializable-catalog
make export-serializable-catalog
make validate-geometry-short
make validate-geometry-falda-evase
make export-universal-short
make export-universal-falda-evase

rm -rf exports
git status --short
```

## 4. Crear tag

```bash
git tag -a v0.2.0 -m "v0.2.0 - MVP motor serializable JSON"
```

## 5. Publicar

```bash
git push origin main
git push origin v0.2.0
```

## 6. Verificacion final

```bash
git log --oneline --decorate --max-count=10
git tag --list "v0.2.0"
```
DOC

python3 - <<'PY'
from pathlib import Path

readme = Path("README.md")
if readme.exists():
    text = readme.read_text(encoding="utf-8")
    marker = "## Release v0.2.0"
    block = """
## Release v0.2.0

El release `v0.2.0` consolida el MVP tecnico del motor serializable JSON.

Capacidades principales:

- prendas definidas por JSON,
- validacion semantica del DSL,
- validacion masiva del catalogo serializable,
- generacion masiva de geometria,
- exportacion masiva SVG/DXF/PDF,
- flujo universal individual para `short_basico` y `falda_evase`.

Comandos principales:

```bash
make validate-garments-json
make validate-serializable-catalog
make generate-serializable-catalog
make export-serializable-catalog
```

Documentacion asociada:

- `docs/47_Fase_38_Documentacion_Checklist_Release_v0_2_0.md`
- `docs/48_Checklist_Release_v0_2_0.md`
- `docs/49_Release_Notes_v0_2_0.md`
- `docs/50_Runbook_Release_v0_2_0.md`
"""
    if marker not in text:
        readme.write_text(text.rstrip() + "\n\n" + block.lstrip(), encoding="utf-8")

changelog = Path("CHANGELOG.md")
if changelog.exists():
    text = changelog.read_text(encoding="utf-8")
    marker = "## v0.2.0"
    block = """
## v0.2.0

MVP tecnico del motor serializable JSON.

### Agregado

- Contrato serializable de prendas JSON.
- Interpretacion de formulas geometricas.
- Registro dinamico de prendas serializables.
- Exportacion universal SVG/DXF/PDF para prendas JSON.
- Prenda `falda_evase` definida desde JSON.
- Validacion geometrica de prendas serializables.
- Validacion semantica del DSL JSON.
- Validacion masiva del catalogo serializable.
- Generacion masiva del catalogo serializable.
- Exportacion masiva SVG/DXF/PDF del catalogo serializable.

### Calidad

- Suite esperada: `141 passed, 7 warnings`.
- Warnings conocidos de dependencias externas `ezdxf`/`pyparsing`.

### Pendientes

- Editor visual del DSL.
- Mas prendas JSON.
- DSL industrial ampliado.
- Empaquetado de exports.
"""
    if marker not in text:
        changelog.write_text(block.lstrip() + "\n" + text.lstrip(), encoding="utf-8")
PY

echo "== Validando documentacion y release candidate =="
make test
make validate-garments-json
make validate-serializable-catalog
make generate-serializable-catalog
make export-serializable-catalog
make validate-geometry-short
make validate-geometry-falda-evase
make export-universal-short
make export-universal-falda-evase

rm -rf exports

echo "== Estado Git =="
git status --short

echo "== Fase 38 aplicada correctamente =="
