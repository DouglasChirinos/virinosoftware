# Fase 40 - GUI para generar/exportar prendas existentes

## Objetivo

Convertir la GUI universal en una primera pantalla de producto para usuario final, enfocada en usar prendas existentes sin terminal.

## Alcance implementado

- La GUI lista prendas registradas desde el catalogo universal.
- Incluye prendas Python y prendas serializables JSON.
- Muestra medidas requeridas segun la prenda seleccionada.
- Precarga valores demo por prenda:
  - `falda_basica`
  - `pantalon_basico`
  - `short_basico`
  - `falda_evase`
- Permite ingresar nombre opcional de patron.
- Genera patron desde pantalla.
- Exporta SVG, DXF y PDF desde pantalla.
- Genera nombres de salida seguros con timestamp para evitar sobrescritura accidental.
- Muestra rutas absolutas de archivos exportados.
- Refuerza validacion de valores numericos ingresados.

## Fuera de alcance

- Registro historico local de patrones generados.
- Consulta de patrones guardados.
- Impresion directa desde GUI.
- Creacion de prendas nuevas desde GUI.
- Editor visual de puntos y lineas.

Estos puntos pertenecen a Fases 41, 42, 43, 44 y 45.

## Comando de uso

```bash
cd /home/antares/Proyecto/motor
make run-gui
```

## Validacion recomendada

```bash
cd /home/antares/Proyecto/motor

make test
make validate-garments-json
make validate-serializable-catalog
make generate-serializable-catalog
make export-serializable-catalog

rm -rf exports
git status --short
```

## Criterio de aceptacion

Un usuario final puede abrir la GUI, seleccionar una prenda existente, ingresar medidas, generar el patron y exportar SVG/DXF/PDF sin editar JSON ni usar terminal.

## Ajuste visual posterior a validacion manual

Durante la validacion manual de la GUI se detecto que el patron se generaba, pero las exportaciones no mostraban las medidas del usuario y algunas anotaciones de puntos cercanos se solapaban.

Correccion aplicada:

- Los exports SVG/PDF incorporan metadatos de prenda y medidas.
- El exportador universal adjunta `garment_code`, `garment_name`, `draft_class_name` y `measurements` a las piezas normalizadas.
- Los labels de puntos en SVG/PDF usan posicionamiento con deteccion basica de colisiones para reducir solapes visuales.
- Las salidas generadas siguen siendo artefactos y no se deben commitear.

## Ajuste visual posterior a validacion manual

Durante la validacion manual de la GUI se detecto que el patron se generaba, pero las exportaciones no mostraban las medidas del usuario y algunas anotaciones de puntos cercanos se solapaban.

Correccion aplicada:

- Los exports SVG/PDF incorporan metadatos de prenda y medidas.
- El exportador universal adjunta `garment_code`, `garment_name`, `draft_class_name` y `measurements` a las piezas normalizadas.
- Los labels de puntos en SVG/PDF usan posicionamiento con deteccion basica de colisiones para reducir solapes visuales.
- Las salidas generadas siguen siendo artefactos y no se deben commitear.
