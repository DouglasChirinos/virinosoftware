# 28. Fase 19 - Inferencia de talla desde medidas

## Objetivo

Permitir que las medidas reales determinen la talla nominal de referencia.

## Alcance aplicado

- `MeasurementDifference`
- `SizeInferenceResult`
- `infer_size_from_measurements()`
- CLI `scripts/infer_size.py`
- Generador personalizado:
  - `scripts/generate_basic_skirt_from_measurements.py`
- Reporte de inferencia de talla.
- Tests automatizados.

## Flujo

```text
Medidas reales
    ↓
Comparacion contra tabla XS/S/M/L/XL
    ↓
Calculo de distancia cintura/cadera
    ↓
Talla nominal mas cercana
    ↓
Diferencias por medida
    ↓
Reporte de inferencia
```

## Ejemplo

```bash
.venv/bin/python scripts/infer_size.py --waist 73 --hip 99
```

Salida esperada:

```text
RECOMMENDED_SIZE: M
DIFF_WAIST: +1.00 cm
DIFF_HIP: +1.00 cm
```

## Generar falda desde medidas

```bash
.venv/bin/python scripts/generate_basic_skirt_from_measurements.py --waist 73 --hip 99 --skirt-length 60
```

## Fuera de alcance

- No se agregan nuevas prendas.
- No se implementa gradacion industrial completa.
- No se reemplaza patron personalizado.
- No se modifican reglas geometricas de la falda.

## Decision tecnica

La talla nominal pasa a ser una referencia, no una entrada obligatoria.
El patron puede generarse desde medidas reales y reportar la talla mas cercana.
