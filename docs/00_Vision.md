# Motor de Patronaje 2D - Alcance y Reglas del Proyecto

## Objetivo

Desarrollar un motor de patronaje 2D en Python capaz de generar patrones
técnicos a partir de medidas del usuario.

## Alcance (MVP)

-   Interfaz con CustomTkinter.
-   Entrada y validación de medidas.
-   Motor geométrico independiente.
-   Generación de una prenda inicial (falda básica).
-   Exportación a SVG.
-   Arquitectura preparada para DXF y PDF.

## Fuera del alcance inicial

-   Modelado 3D.
-   Simulación de telas.
-   Gradación industrial.
-   Nesting.
-   Corte automático.

## Principios de arquitectura

1.  Separar geometría y reglas de patronaje.
2.  Una prenda = un módulo.
3.  Sin lógica de interfaz dentro del motor.
4.  Todas las fórmulas documentadas.
5.  Pruebas unitarias para el motor.

## Estructura propuesta

``` text
/home/antares/Proyecto/motor/
├── app/
├── engine/
├── exports/
├── tests/
├── docs/
├── docker/
└── README.md
```

## Tecnologías

-   Python
-   CustomTkinter
-   svgwrite
-   shapely
-   ezdxf
-   reportlab
-   pytest
-   Docker
-   Git

## Convenciones

-   Nombres y comentarios en español técnico.
-   Tipado (`typing`) obligatorio.
-   Clases con responsabilidad única.
-   Sin código duplicado.

## Flujo

1.  Capturar medidas.
2.  Validar.
3.  Calcular puntos.
4.  Generar geometría.
5.  Visualizar.
6.  Exportar.

## Hoja de ruta

### Fase 1

-   Motor geométrico.
-   Sistema de medidas.
-   SVG.

### Fase 2

-   Falda básica.

### Fase 3

-   Pantalón.

### Fase 4

-   Blusa y manga.

### Fase 5

-   DXF y PDF.

## Criterios de éxito

-   Resultados reproducibles.
-   Código modular.
-   Fácil incorporación de nuevas prendas.
-   Documentación actualizada con cada cambio.
