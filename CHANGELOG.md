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

# CHANGELOG

## v0.1.0 - MVP motor patronaje 2D

Estado: preparado para release.

### Incluido

- Estructura profesional del proyecto Python.
- Motor geometrico base.
- Compatibilidad legacy de geometria.
- Sistema de medidas corporales en centimetros.
- Validaciones de dominio para medidas.
- Generador MVP de falda basica.
- Exportacion SVG.
- Exportacion DXF.
- Exportacion PDF.
- GUI minima con CustomTkinter.
- Logging operacional con Loguru.
- Versionado interno de patrones.
- Reporte tecnico Markdown.
- QA geometrico.
- Reporte QA.
- Margen de costura MVP.
- Contorno cerrado de margen.
- Interseccion de offsets.
- Control inicial de esquinas miter/bevel.
- Reporte tecnico de margen.
- Flujo Git main/develop/feature documentado.
- Checklist de release v0.1.0.

### Validaciones esperadas

```bash
make test
make run-qa
make generate-all-exports
make show-reports
```

### Limitaciones conocidas

- Solo incluye falda basica MVP.
- No incluye pantalon, blusa, manga ni camisa.
- No incluye curvas industriales avanzadas.
- No incluye fillets reales.
- No incluye motor booleano completo.
- No incluye escalado/tallaje.
- No incluye API web.
- No incluye persistencia de proyectos.
