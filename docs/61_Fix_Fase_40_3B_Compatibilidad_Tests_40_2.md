# Fix Fase 40.3B — Compatibilidad de tests 40.2

## Problema

Fase 40.3B introdujo la regla correcta de producto:

```text
Si existe curva estructural de contorno, no debe coexistir la curva visual punteada equivalente.
```

Los tests historicos de Fase 40.2 seguian esperando labels de curvas visuales punteadas:

- `Curva cadera costado`
- `Correccion suave de bajo`
- `Curva tiro/costado MVP`
- `Curva tiro/entrepierna MVP`

Por eso `make validate-fase-40-3` fallaba aunque Fase 40.3B estuviera funcionando correctamente.

## Decision

Actualizar los tests de Fase 40.2 para aceptar dos estados validos:

1. Estado historico: curva visual punteada.
2. Estado evolucionado: curva estructural semantica.

Cuando el SVG contiene `class="structural-curve"`, el test exige que no exista `stroke-dasharray="6 3"` para evitar duplicidad visual.

## Criterio tecnico

La prueba ya no valida un texto viejo. Valida el contrato de producto:

- debe existir una curva exportada;
- si es estructural, debe ser la unica curva visible del tramo;
- no debe quedar overlay punteado duplicado.

## Validacion

```bash
make validate-fase-40-3b
make validate-fase-40-3
make validate-piece-completeness
```
