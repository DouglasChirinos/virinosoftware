# Fase 41 - Contrato de transformaciones editables

## Decision de producto

El motor ya no debe seguir acumulando solo logica automatica de patronaje. El siguiente salto es permitir que el usuario trabaje sobre una variante editable del patron generado.

La regla base queda fija:

```text
patron_base generado por medidas -> variante editable del usuario
```

El patron base no se destruye. Las transformaciones se guardan como operaciones replayables sobre una copia.

## Alcance MVP

Esta fase no implementa un CAD completo ni un editor visual todavia. Crea el contrato tecnico que hara posible la Fase 42.

Operaciones soportadas:

- `move_point`: mover un punto por `dx/dy`.
- `move_line`: desplazar una linea completa.
- `scale_line`: estirar o acortar una linea con ancla `start`, `end` o `center`.
- `adjust_curve`: mover controles Bezier de una curva estructural.

## Modelo de variante

```json
{
  "pattern_id": "pantalon_basico_001",
  "base_garment": "pantalon_basico",
  "variant_name": "Pantalon ajustado tiro posterior",
  "transformations": [
    {
      "type": "move_point",
      "piece": "Pantalon basico posterior",
      "point": "B",
      "dx": -2.0,
      "dy": 0.0
    },
    {
      "type": "adjust_curve",
      "piece": "Pantalon basico posterior",
      "curve": "crotch_curve",
      "control_delta": {
        "c1_dx": -3.0,
        "c1_dy": 0.0,
        "c2_dx": -5.0,
        "c2_dy": 1.0
      }
    }
  ]
}
```

## Criterio tecnico

- La funcion `apply_transformations` devuelve copias transformadas.
- La geometria base permanece intacta.
- Cada pieza transformada recibe metadata `editable_variant`.
- Las operaciones deben fallar rapido si la pieza, punto, linea o curva no existe.

## Archivos agregados

- `engine/transformations/__init__.py`
- `engine/transformations/operations.py`
- `engine/transformations/apply.py`
- `tests/test_fase_41_transformaciones_editables.py`

## Validacion

```bash
make validate-fase-41
```

## Pendiente para Fase 42

Crear editor visual MVP en GUI:

- Canvas de patron.
- Seleccion de pieza.
- Seleccion de punto, linea o curva.
- Movimiento con mouse o campos numericos.
- Deshacer.
- Guardar variante.
- Exportar variante a SVG/PDF/DXF.
