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
