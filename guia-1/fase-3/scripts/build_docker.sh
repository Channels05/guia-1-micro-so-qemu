#!/usr/bin/env sh
# Fase 3: ejecuta scripts/build.sh dentro de un contenedor Debian 12.
# Sirve en Windows (Git Bash o MSYS2), macOS y Linux con Docker instalado.
# Uso:  sh guia-1/fase-3/scripts/build_docker.sh
set -e
cd "$(dirname "$0")/.."

docker build -t micro-so-f3 -f scripts/Dockerfile scripts

# En Git Bash / MSYS2, pwd -W entrega la ruta con formato Windows (C:/...)
DIR=$(pwd -W 2>/dev/null || pwd)
MSYS_NO_PATHCONV=1 docker run --rm -v "$DIR:/trabajo" -w /trabajo micro-so-f3 sh scripts/build.sh
