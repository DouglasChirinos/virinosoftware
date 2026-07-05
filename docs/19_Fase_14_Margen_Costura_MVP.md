# 19. Fase 14 - Margen de costura MVP

## Objetivo

Agregar margen de costura como capacidad transversal del motor antes de avanzar a nuevas prendas.

## Alcance aplicado

- Configuracion de margen de costura en centimetros.
- Offset paralelo simple por linea.
- Pieza base y pieza con margen.
- Diferenciacion de lineas:
  - `pattern`
  - `seam_allowance`
  - `helper`
- SVG con margen punteado.
- DXF por capas:
  - `PATTERN`
  - `SA`
  - `HELPER`
- PDF con margen punteado.
- QA basico de margen de costura.
- Tests automatizados.

## Unidad

El margen de costura usa la unidad oficial del motor:

```text
cm
```

## Configuracion MVP

```python
SeamAllowanceConfig(
    default_cm=1.0,
    hem_cm=3.0,
    waist_cm=1.0,
    side_cm=1.5,
)
```

## Limitacion conocida

Este MVP aplica offsets por linea.

Todavia no resuelve contorno industrial completo con:

- esquinas unidas,
- miter,
- fillets,
- union limpia de offsets,
- recorte de intersecciones.

Eso queda para una fase posterior.
