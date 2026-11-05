#!/usr/bin/env sh
# Reconstruye las tres fases y vuelve a tomar todas las capturas de QEMU,
# para que las evidencias correspondan siempre a la versión actual del código.
# Requiere: nasm, qemu-system-i386 y python en el PATH; Docker para la Fase 3
# (o las herramientas de Linux, ver fase-3/README.md).
# Uso (desde guia-1/):  sh herramientas/generar_evidencias.sh
set -e
cd "$(dirname "$0")/.."
CAP="python herramientas/captura_qemu.py"

echo "== Fase 1"
sh fase-1/build.sh
$CAP --paso 2:fase-1/evidencias/arranque_f1-qemu.png \
     -- -drive file=fase-1/build/boot_f1.bin,format=raw,if=floppy

echo "== Fase 2"
sh fase-2/scripts/build.sh
E=fase-2/evidencias
$CAP --paso 0.3:$E/f2_01_etapa1.png \
     --paso 2.5:$E/arranque_f2-qemu.png \
     --paso 0:1@$E/f2_03_opcion1_info.png   --paso 0:ret \
     --paso 0:3@$E/f2_05_opcion3_reloj.png  --paso 0:ret \
     --paso 0:x@$E/f2_06_tecla_invalida.png \
     --paso 0:f1@$E/f2_06b_tecla_sin_ascii.png \
     --paso 0:2@$E/f2_04a_galope_cuenta.png \
     --paso 3.4:$E/f2_04b_galope_carrera.png \
     --paso 3.5:$E/f2_04c_galope_final.png --paso 0:ret \
     --paso 0:0@$E/f2_07_detenido.png \
     -- -drive file=fase-2/build/disco_f2.img,format=raw,if=floppy
$CAP --paso 2:$E/f2_08_fallo_sin_etapa2.png \
     -- -drive file=fase-2/build/disco_f2_sin_etapa2.img,format=raw,if=floppy

echo "== Fase 3"
sh fase-3/scripts/build_docker.sh
E=fase-3/evidencias
ISO=fase-3/build/micro_so_f3.iso
$CAP --paso 3:$E/f3_01_menu_grub.png --paso 0:ret \
     --paso 0.7:$E/f3_02_patron_prueba.png \
     --paso 4:$E/arranque_f3-qemu.png \
     -- -cdrom $ISO -serial file:$E/serial_f3_normal.log
$CAP --paso 3:down,ret --paso 4:$E/f3_04_prueba_imagen_corrupta.png \
     -- -cdrom $ISO -serial file:$E/serial_f3_imagen_corrupta.log
$CAP --paso 3:down,down,ret --paso 3:$E/f3_05_prueba_sin_grafico.png \
     -- -cdrom $ISO -serial file:$E/serial_f3_sin_grafico.log
cp fase-3/assets/original/caballo_f3.png fase-3/figuras/imagen_f3.png

echo "OK: evidencias regeneradas"
