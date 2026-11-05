# Entorno de construcción de la Fase 3 (Debian 12 "bookworm")
# gcc + binutils generan un ELF32 i386 freestanding; grub-mkrescue + xorriso
# arman la ISO arrancable con GRUB para BIOS (i386-pc).
FROM debian:bookworm-slim

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
        gcc binutils nasm python3 file \
        grub-common grub-pc-bin xorriso mtools \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /trabajo
