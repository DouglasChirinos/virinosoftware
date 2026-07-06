# Fase 40.3C — Direccion de concavidad en curvas estructurales

## Decision tecnica

Fase 40.3B quedo tecnicamente validada, pero visualmente no era suficiente para pantalon y short. El problema era patronistico:

```text
Una curva de tiro no solo debe ser concava.
Debe entrar hacia dentro.
```

Por eso Fase 40.3C agrega el campo:

```text
concavity_direction
```

## Contrato semantico

Valores iniciales:

```text
inward            -> curva entra hacia dentro.
inward_deeper     -> curva entra hacia dentro con mayor profundidad, usado para posterior.
outward           -> curva proyecta volumen hacia afuera.
mixed_transition  -> transicion con comportamiento mixto.
none              -> no aplica.
```

## Reglas de patronaje fijadas

```text
Curva de cadera:
- normalmente convexa hacia afuera.

Curva de tiro:
- concava hacia dentro.

Tiro posterior:
- concavo hacia dentro y mas profundo que delantero.

Entrepierna:
- puede ser mixta.

Boca de pierna:
- puede ser convexa o mixta segun diseno.
```

## Cambios implementados

- `engine/exports/structural_curves.py`
  - agrega `concavity_direction` al payload de curvas estructurales.
  - marca `crotch_curve` de delantero como `inward`.
  - marca `crotch_curve` de posterior como `inward_deeper`.
  - mueve puntos de control Bezier del tiro hacia dentro, no hacia afuera.

- `tests/test_fase_40_3c_concavity_direction.py`
  - valida que toda curva estructural exponga `concavity_direction`.
  - valida que `crotch_curve` nunca sea convexa.
  - valida que `crotch_curve` tenga direccion inward/inward_deeper.
  - valida que el posterior sea `inward_deeper`.
  - valida que los controles Bezier del tiro entren hacia dentro.

## Advertencia vigente

Esto mejora el criterio de patronaje, pero no convierte pantalon ni short en patrones industriales. Aun faltan:

- altura de tiro formal;
- gancho delantero;
- gancho posterior;
- linea de rodilla;
- aplomo / hilo de tela;
- piquetes;
- boca de pierna real;
- metodologia industrial de entrepierna.

## Validacion

```bash
make validate-fase-40-3c
make validate-fase-40-3b
make validate-fase-40-3
make validate-piece-completeness
```

Luego reexportar desde GUI:

```text
pantalon_basico
short_basico
```

Criterio visual de aceptacion:

```text
- La curva de tiro debe entrar hacia dentro.
- El posterior debe entrar mas profundo que el delantero.
- No deben reaparecer curvas punteadas duplicadas.
- Las piezas deben seguir separadas y legibles.
```
