# 05 - GUI MVP

## Objetivo

Crear una interfaz mínima en CustomTkinter para validar el flujo de usuario:

1. Capturar medidas.
2. Validar datos.
3. Generar patrón.
4. Exportar SVG.

## Alcance actual

- Formulario de falda básica.
- Validación por el motor de medidas.
- Generación de SVG.
- Mensaje de confirmación.

## Fuera de alcance por ahora

- Vista previa embebida.
- Edición manual de puntos.
- Exportación DXF/PDF desde GUI.
- Gestión de clientes.
- Base de datos.

## Regla de arquitectura

La GUI no calcula fórmulas de patronaje. Solo captura datos y llama controladores.
