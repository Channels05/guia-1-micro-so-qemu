#!/usr/bin/env python3
"""Convierte el dibujo ASCII del caballo al flujo de bytes de las fases 1 y 2.

El dibujo se escribe aquí como texto plano (más fácil de diseñar y revisar) y
este script genera las líneas `db` que se pegan en boot_f1.asm y dibujo.inc:
    - una racha de 2 o más espacios se codifica como "avanzar N columnas"
      (bytes 1..31, sin usar 10, que es el salto de línea)
    - el color cambia según el tipo de carácter (cola, ojo, pasto, cuerpo)

Uso:  python herramientas/ascii_a_nasm.py
"""

CABALLO = [
    r"                              _/\ ",
    r"                            _/~~ \ ",
    r"                          _/~~ o  `-._",
    r"                        _/~~   ,-.___)",
    r"                      _/~~    /",
    r"     ___.------------'~~     |",
    r"  ,-'                        |",
    r"~(                           /",
    r"~~\   .------------------.  /\ ",
    r" ~ /  /\                 \  \ `-----.",
    r"  / /  \ \                \  \`-----'",
    r" / /    \ \               /  /",
    r"/_/      \_\             /__/",
    r" ,  .,  ' , .  ,  ., '  ,  . ,  .,  ' ,",
]
FILA_PASTO = len(CABALLO) - 1


def color(fila, c):
    if fila == FILA_PASTO:
        return "VERDE"
    if c == "~":
        return "CAFE"
    if c == "o":
        return "BLANCO"
    return "AMARILLO"


def a_nasm(filas):
    lineas, actual, total = [], None, 0
    for f, texto in enumerate(filas):
        texto = texto.rstrip()
        partes, i = [], 0
        while i < len(texto):
            if texto[i] == " ":
                j = i
                while j < len(texto) and texto[j] == " ":
                    j += 1
                n = j - i
                if n == 1 and partes and partes[-1].startswith('"'):
                    partes[-1] = partes[-1][:-1] + ' "'
                else:
                    while n > 0:                        # 10 = NL: se parte en 9 + resto
                        paso = min(n, 31)
                        if paso == 10:
                            paso = 9
                        partes.append(str(paso))
                        n -= paso
                i = j
                continue
            col = color(f, texto[i])
            if col != actual:
                partes.append(f"C({col})")
                actual = col
            if partes and partes[-1].startswith('"'):
                partes[-1] = partes[-1][:-1] + texto[i] + '"'
            else:
                partes.append(f'"{texto[i]}"')
            i += 1
        partes.append("NL")
        lineas.append("    db " + ", ".join(partes))
    # bytes: números y C() = 1 byte; cadenas = su largo
    for l in lineas:
        for p in l[7:].split(", "):
            total += len(p) - 2 if p.startswith('"') else 1
    return lineas, total


if __name__ == "__main__":
    lineas, total = a_nasm(CABALLO)
    print("\n".join(lineas))
    print(f"; {total} bytes")
