#!/usr/bin/env python3
"""Arranca QEMU sin ventana, envía teclas y guarda capturas de su pantalla.

Las capturas se toman con el comando `screendump` del monitor de QEMU, es
decir, son el contenido real de la tarjeta de video emulada.

Ejemplo:
    python herramientas/captura_qemu.py \
        --paso 2:fase-1/evidencias/arranque_f1-qemu.png \
        -- -drive file=fase-1/build/boot_f1.bin,format=raw,if=floppy

Cada --paso tiene una de estas formas:
    ESPERA:archivo.png          esperar y capturar
    ESPERA:teclas@archivo.png   esperar, enviar teclas y capturar
    ESPERA:teclas               esperar y enviar teclas, sin capturar
    ESPERA   segundos a esperar antes del paso
    teclas   teclas de QEMU separadas por coma (p. ej. "1", "down,ret")
"""
import argparse
import os
import shutil
import socket
import subprocess
import sys
import time


def monitor(sock, comando):
    sock.sendall((comando + "\n").encode())
    time.sleep(0.3)
    try:
        sock.recv(65536)
    except (socket.timeout, ConnectionError):
        pass  # tras "quit" QEMU cierra la conexión


def main():
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--qemu", default="qemu-system-i386")
    p.add_argument("--puerto", type=int, default=45454)
    p.add_argument("--paso", action="append", required=True)
    p.add_argument("qemu_args", nargs=argparse.REMAINDER)
    a = p.parse_args()

    qemu = shutil.which(a.qemu) or a.qemu
    args = [x for x in a.qemu_args if x != "--"]
    cmd = [qemu, "-display", "none",
           "-monitor", f"tcp:127.0.0.1:{a.puerto},server=on,wait=off"] + args
    proc = subprocess.Popen(cmd)
    try:
        for _ in range(50):
            try:
                sock = socket.create_connection(("127.0.0.1", a.puerto), timeout=1)
                break
            except OSError:
                time.sleep(0.2)
        else:
            sys.exit("No se pudo conectar al monitor de QEMU")
        sock.settimeout(0.5)
        monitor(sock, "")

        for paso in a.paso:
            espera, resto = paso.split(":", 1)
            if "@" in resto:
                teclas, archivo = resto.split("@", 1)
            elif resto.endswith(".png"):
                teclas, archivo = "", resto
            else:
                teclas, archivo = resto, ""
            time.sleep(float(espera))
            for t in filter(None, teclas.split(",")):
                monitor(sock, f"sendkey {t}")
            if not archivo:
                continue
            time.sleep(0.5)
            os.makedirs(os.path.dirname(os.path.abspath(archivo)), exist_ok=True)
            monitor(sock, f"screendump {os.path.abspath(archivo)} -f png")
            print("captura:", archivo)
        monitor(sock, "quit")
    finally:
        try:
            proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            proc.kill()


if __name__ == "__main__":
    main()
