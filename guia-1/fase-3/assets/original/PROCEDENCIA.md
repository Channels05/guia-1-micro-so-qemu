# Procedencia de la imagen

| Campo | Valor |
| :--- | :--- |
| Archivo | `caballo_f3.png` |
| Autoría | Imagen propia, creada para esta guía: un caballo al galope dibujado con puntos brillantes, como una matriz de caracteres encendidos, sobre un atardecer y un potrero difuminados. La silueta es la misma que se usó para el caballo ASCII de las fases 1 y 2. |
| Cómo se generó | `python3 generar_imagen.py caballo_f3.png`. El script define la silueta con elipses y cápsulas (cuerpo, cuello, cabeza, cola y patas), pinta el fondo con degradados y ruido de senos, y escribe el PNG solo con la biblioteca estándar de Python (`zlib`, `struct`). No hay azar real (los "puntos al azar" salen de un hash fijo), así que el resultado es siempre el mismo. |
| Referencia de estilo | La idea de un caballo hecho de puntos que brillan sobre una foto difusa se tomó de una imagen vista en internet. **Esa imagen no se usa ni se incluye en el repositorio:** no se copió ni se calcó; silueta, colores y composición se diseñaron desde cero. |
| Dimensiones | 200 × 150 píxeles |
| Canales / profundidad | RGB, 3 canales de 8 bits (24 bits por píxel), sin canal alfa |
| Formato | PNG (compresión DEFLATE, filtro 0 por fila, sin entrelazado) |
| Licencia | Obra propia; se permite redistribuirla junto con este repositorio (CC BY 4.0). No contiene material de terceros. |

## Conversión al formato del kernel

```bash
python3 ../converted/png_a_img.py caballo_f3.png ../converted/imagen.img
```

`png_a_img.py` decodifica el PNG (inflado con `zlib` y deshacer los filtros por fila: None, Sub, Up, Average y Paeth) y escribe `imagen.img` en formato **IMG1**:

| Desplazamiento | Tamaño | Contenido |
| :--- | :--- | :--- |
| 0 | 4 B | firma `IMG1` |
| 4 | 4 B | ancho = 200 (uint32 little endian) |
| 8 | 4 B | alto = 150 |
| 12 | 4 B | bytes por píxel = 3 |
| 16 | 90 000 B | píxeles R, G, B: filas de arriba hacia abajo, cada fila de izquierda a derecha |

Total: 90 016 bytes, frente a los 20 559 del PNG. Ese tamaño es el costo de que el kernel lea los píxeles directamente, sin decodificador.
