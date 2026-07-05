# Motor de Patronaje 2D

MVP de un motor CAD modular para patronaje 2D en Python.

## Objetivo

Separar el nucleo geometrico de las reglas de patronaje y de la interfaz grafica.

## Flujo esperado

Usuario -> Medidas -> Motor matematico -> Motor geometrico -> SVG/DXF/PDF

## Comandos principales

```bash
make install
make test
make lint
make run
```

## Ruta sugerida

```bash
/home/antares/Proyecto/motor
```

## Documento rector

Colocar el documento `Motor_Patronaje_2D_Alcance.md` dentro de `docs/` y, preferiblemente, renombrarlo o copiarlo como:

```bash
docs/00_Vision.md
```

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
