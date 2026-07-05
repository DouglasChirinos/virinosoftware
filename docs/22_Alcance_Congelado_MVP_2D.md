# 22. Alcance congelado MVP 2D

## Estado

MVP 2D congelado para version `v0.1.0`.

## Objetivo del MVP

Construir una base tecnica funcional para un motor de patronaje 2D con:

- geometria base,
- medidas corporales,
- generacion de falda basica,
- exportaciones,
- validaciones,
- control de calidad,
- margen de costura,
- reportes tecnicos,
- flujo Git profesional.

## Unidad oficial

```text
centimetros (cm)
```

Todas las medidas internas del motor usan centimetros.

## Incluido en MVP

### Geometria

- Punto.
- Linea.
- Curva base.
- Poligono base.
- Operaciones legacy de compatibilidad.
- Interseccion de lineas.
- Offsets paralelos.
- Intersecciones de offsets.
- Analisis de esquinas miter/bevel.

### Medidas

- `BodyMeasurements`.
- Validaciones de rangos.
- Rechazo de unidades distintas a `cm`.

### Prenda MVP

- Falda basica delantera.
- API legacy compatible.
- Versionado interno del patron.

### Exportaciones

- SVG.
- DXF.
- PDF.

### Calidad

- QA geometrico.
- QA de margen de costura.
- QA de contorno cerrado.
- QA de metadata de esquinas.
- Reportes Markdown.

### Margen de costura

- Margen por configuracion.
- Contorno cerrado inicial.
- Control de miter.
- Fallback bevel.
- Metadata de margen.

## Excluido del MVP

- Pantalon.
- Blusa.
- Manga.
- Camisa.
- Curvas industriales avanzadas.
- Fillets reales.
- Motor booleano de poligonos.
- Escalado/tallaje.
- Tendido/imposicion.
- Piquetes industriales avanzados.
- Compensacion por tipo de tela.
- Interfaz grafica final.
- Persistencia de proyectos.
- API web.

## Criterio de cierre

El MVP se considera cerrado cuando:

```bash
make test
make run-qa
make generate-all-exports
make show-reports
```

queda verde en `develop`.
