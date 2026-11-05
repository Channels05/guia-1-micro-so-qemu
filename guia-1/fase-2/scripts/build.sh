#!/usr/bin/env sh
# Fase 2: ensambla ambas etapas, arma la imagen de disquete y la verifica.
# Uso (desde cualquier carpeta):
#   sh guia-1/fase-2/scripts/build.sh          construir y verificar
#   sh guia-1/fase-2/scripts/build.sh run      arrancar en QEMU
#   sh guia-1/fase-2/scripts/build.sh fallo    arrancar la imagen sin etapa 2
set -e
cd "$(dirname "$0")/.."

SRC=src
OUT=build
TOTAL=2880                      


valor() { awk -v k="$1" '$1 == k { print $3 }' "$SRC/disposicion.inc"; }
LBA=$(valor ETAPA2_LBA)
SECTORES=$(valor ETAPA2_SECTORES)

mkdir -p "$OUT"
nasm -f bin -I "$SRC/" "$SRC/boot_f2.asm"   -o "$OUT/boot_f2.bin"   -l "$OUT/boot_f2.lst"
nasm -f bin -I "$SRC/" "$SRC/etapa2_f2.asm" -o "$OUT/etapa2_f2.bin" -l "$OUT/etapa2_f2.lst"

# Imagen normal: etapa 1 en LBA 0, etapa 2 desde LBA $LBA, resto en ceros
dd if=/dev/zero          of="$OUT/disco_f2.img" bs=512 count=$TOTAL 2>/dev/null
dd if="$OUT/boot_f2.bin"   of="$OUT/disco_f2.img" bs=512 conv=notrunc 2>/dev/null
dd if="$OUT/etapa2_f2.bin" of="$OUT/disco_f2.img" bs=512 seek="$LBA" conv=notrunc 2>/dev/null

# Imagen de prueba de fallo controlado: solo la etapa 1 (sin etapa 2)
dd if=/dev/zero          of="$OUT/disco_f2_sin_etapa2.img" bs=512 count=$TOTAL 2>/dev/null
dd if="$OUT/boot_f2.bin"   of="$OUT/disco_f2_sin_etapa2.img" bs=512 conv=notrunc 2>/dev/null

# Verificaciones
bytes() { wc -c < "$1" | tr -d ' '; }
hexa()  { od -An -tx1 -j"$2" -N"$3" "$1" | tr -d ' \n'; }
error() { echo "ERROR: $*" >&2; exit 1; }

[ "$(bytes $OUT/boot_f2.bin)" -eq 512 ]                 || error "boot_f2.bin no mide 512 bytes"
[ "$(hexa $OUT/boot_f2.bin 510 2)" = "55aa" ]           || error "boot_f2.bin sin firma 55 aa"
[ "$(bytes $OUT/etapa2_f2.bin)" -eq $((SECTORES * 512)) ] || error "etapa2_f2.bin no mide $SECTORES sectores"
[ "$(bytes $OUT/disco_f2.img)" -eq $((TOTAL * 512)) ]   || error "disco_f2.img no mide 1,44 MB"
[ "$(hexa $OUT/disco_f2.img 510 2)" = "55aa" ]          || error "disco_f2.img sin firma en LBA 0"
[ "$(hexa $OUT/disco_f2.img $((LBA * 512)) 4)" = "45545032" ] || error "no se encuentra ETP2 en LBA $LBA"

echo "boot_f2.bin    $(bytes $OUT/boot_f2.bin) bytes, firma $(hexa $OUT/boot_f2.bin 510 2)   -> LBA 0"
echo "etapa2_f2.bin  $(bytes $OUT/etapa2_f2.bin) bytes ($SECTORES sectores), firma ETP2 -> LBA $LBA..$((LBA + SECTORES - 1))"
echo "disco_f2.img   $(bytes $OUT/disco_f2.img) bytes ($TOTAL sectores)"
echo "OK: imagen verificada"

case "$1" in
    run)   qemu-system-i386 -drive file=$OUT/disco_f2.img,format=raw,if=floppy ;;
    fallo) qemu-system-i386 -drive file=$OUT/disco_f2_sin_etapa2.img,format=raw,if=floppy ;;
esac
