# Fase 31 - Consolidacion del contrato exportable serializable

## Objetivo

Consolidar el contrato tecnico entre prendas serializables JSON y el exportador universal SVG/DXF/PDF.

La Fase 30 dejo funcional la exportacion universal de `short_basico`, pero el `exporter.py` quedo con logica defensiva agregada durante varios fixes. Esta fase limpia y formaliza ese contrato para que futuras prendas JSON no dependan de parches acumulados.

## Alcance

- Refactor controlado de `engine/generation/exporter.py`.
- Consolidacion de helpers internos para puntos y lineas serializables.
- Tests unitarios especificos del contrato exportable serializable.
- Validacion completa de generacion y exportacion existente.
- No se crean prendas nuevas.
- No se toca GUI.
- No se cambia el DSL JSON.

## Contrato exportable soportado

El exportador universal ahora acepta piezas con:

### Puntos

Objetos con atributos:

```python
point.x
point.y
```

Tuplas/listas numericas:

```python
(0.0, 0.0)
[21.0, 0.0]
```

Diccionarios:

```python
{"x": 0.0, "y": 0.0}
```

### Lineas

Lineas clasicas con:

```python
line.start
line.end
```

Referencias serializables por tupla/lista:

```python
("A", "B")
```

Referencias serializables por mapping:

```python
{"start": "A", "end": "B", "name": "costado", "kind": "pattern"}
```

## Archivos modificados

```text
engine/generation/exporter.py
tests/test_exporter_serializable_contract.py
docs/40_Fase_31_Consolidacion_Contrato_Exportable_Serializable.md
scripts/76_fase_31_consolidacion_contrato_exportable_serializable.sh
```

## Validaciones

```bash
make test
make list-garments
make generate-pattern
make generate-basic-pants
make generate-universal-short
make generate-serializable-short
make export-pattern
make export-basic-pants
make export-universal-short
```

## Resultado esperado

```text
short_basico sigue exportando SVG/DXF/PDF por flujo universal.
El contrato serializable queda cubierto con tests unitarios especificos.
No se rompe exportacion tradicional de falda_basica ni pantalon_basico.
```
