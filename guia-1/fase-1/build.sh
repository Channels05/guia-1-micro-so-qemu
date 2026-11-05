#!/usr/bin/env sh
# Fase 1: ensambla el sector de arranque y comprueba tamaño y firma.
# Uso (desde cualquier carpeta):  sh guia-1/fase-1/build.sh [run]
set -e
cd "$(dirname "$0")"
mkdir -p build

nasm -f bin boot_f1.asm -o build/boot_f1.bin -l build/boot_f1.lst

tamano=$(wc -c < build/boot_f1.bin | tr -d ' ')
firma=$(od -An -tx1 -j510 -N2 build/boot_f1.bin | tr -d ' \n')
echo "build/boot_f1.bin: $tamano bytes, bytes 510-511 = $firma"

if [ "$tamano" -ne 512 ] || [ "$firma" != "55aa" ]; then
    echo "ERROR: el sector debe medir 512 bytes y terminar en 55 aa" >&2
    exit 1
fi
echo "OK: sector de arranque valido"

if [ "$1" = "run" ]; then
    qemu-system-i386 -drive file=build/boot_f1.bin,format=raw,if=floppy
fi
