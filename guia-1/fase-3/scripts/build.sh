#!/usr/bin/env sh
# Fase 3: compila el kernel, convierte la imagen y genera la ISO con GRUB.
# Requiere Linux (o el contenedor de scripts/Dockerfile) con:
#   gcc, binutils (ld), nasm, python3, grub-mkrescue (grub-pc-bin), xorriso
# Uso:  sh scripts/build.sh            (desde guia-1/fase-3)
#       sh scripts/build_docker.sh     (en Windows/macOS, vía Docker)
set -e
cd "$(dirname "$0")/.."

OUT=build
OBJ=$OUT/obj
ISO=$OUT/iso
CFLAGS="-m32 -march=i686 -mgeneral-regs-only -std=c11 -O2 -Wall -Wextra \
        -ffreestanding -fno-builtin -fno-pie -fno-stack-protector \
        -fno-asynchronous-unwind-tables"

rm -rf "$OBJ" "$ISO"
mkdir -p "$OBJ" "$ISO/boot/grub"

# 1. Kernel: entrada en ensamblador + C freestanding, enlazado en 1 MiB
nasm -f elf32 kernel/boot_f3.asm -o "$OBJ/boot_f3.o"
for c in kernel/*.c; do
    gcc $CFLAGS -c "$c" -o "$OBJ/$(basename "$c" .c).o"
done
ld -m elf_i386 -nostdlib -T kernel/linker.ld -o "$OUT/kernel_f3.elf" "$OBJ"/*.o

file "$OUT/kernel_f3.elf"
grub-file --is-x86-multiboot2 "$OUT/kernel_f3.elf" \
    && echo "OK: kernel_f3.elf tiene una cabecera Multiboot2 valida" \
    || { echo "ERROR: cabecera Multiboot2 no reconocida" >&2; exit 1; }

# 2. Imagen: PNG original -> píxeles RGB888 sin compresión (formato IMG1)
python3 assets/converted/png_a_img.py assets/original/caballo_f3.png assets/converted/imagen.img
head -c 4096 assets/converted/imagen.img > "$OUT/imagen_corrupta.img"   # prueba de error

# 3. ISO arrancable: GRUB (BIOS) + kernel + módulos
cp "$OUT/kernel_f3.elf"           "$ISO/boot/"
cp assets/converted/imagen.img    "$ISO/boot/"
cp "$OUT/imagen_corrupta.img"     "$ISO/boot/"
cp boot/grub.cfg                  "$ISO/boot/grub/"
grub-mkrescue -o "$OUT/micro_so_f3.iso" "$ISO" 2> "$OUT/grub-mkrescue.log" \
    || { cat "$OUT/grub-mkrescue.log" >&2; exit 1; }

# 4. Registro de versiones de la cadena de construcción
{
    echo "Construido: $(date -u '+%Y-%m-%d %H:%M UTC')"
    gcc --version | head -n 1
    ld --version | head -n 1
    nasm -v
    grub-mkrescue --version
    xorriso -version 2>/dev/null | head -n 1
    python3 --version
} > "$OUT/versiones.txt"

ls -l "$OUT/kernel_f3.elf" "$OUT/micro_so_f3.iso" assets/converted/imagen.img
echo "OK: build/micro_so_f3.iso generada"
