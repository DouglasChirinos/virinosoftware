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
