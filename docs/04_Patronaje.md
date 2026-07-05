# 04 - Patronaje

## Prenda MVP

La primera prenda del motor será una falda básica recta porque permite validar el flujo completo con pocas reglas:

1. Medidas corporales.
2. Fórmulas de patronaje.
3. Generación de puntos.
4. Líneas y curvas.
5. Exportación SVG.

## Medidas iniciales

- Cintura.
- Cadera.
- Largo de falda.
- Bajada de cadera.
- Holgura de cadera.
- Holgura de cintura.

## Reglas de control

- Las fórmulas deben vivir en `engine/garments/*`.
- Las fórmulas no deben generar SVG directamente.
- Las prendas devuelven piezas geométricas.
- La validación de medidas vive en `engine/measurements`.

## Advertencia técnica

Las fórmulas iniciales son una línea base de software para validar el motor, no una norma industrial definitiva de patronaje. Cualquier ajuste experto debe registrarse en documentación y pruebas.
