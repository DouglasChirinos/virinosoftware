# 17. Fix Loguru Retention

## Problema

La Fase 12 configuro Loguru con:

```python
retention="10 files"
```

Ese valor no es valido para Loguru y genera:

```text
ValueError: Invalid unit value while parsing duration: 'files'
```

## Decision

Se corrige a:

```python
retention=10
```

Esto conserva hasta 10 archivos rotados.

## Validacion esperada

```bash
make test
make generate-all-exports
make show-exports
make show-reports
```

Debe generar:

```text
logs/motor_patronaje.log
reports/falda_basica_mvp_reporte.md
exports/svg/falda_basica_mvp.svg
exports/dxf/falda_basica_mvp.dxf
exports/pdf/falda_basica_mvp.pdf
```
