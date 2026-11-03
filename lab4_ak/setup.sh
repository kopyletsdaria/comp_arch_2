#!/bin/bash
set -euo pipefail

WORK=${WORK:-/work}
mkdir -p "$WORK/src"

if [ -f "$WORK/.setup_complete" ]; then
    echo "Середовище вже налаштовано."
    exit 0
fi

export DEBIAN_FRONTEND=noninteractive

echo ">>> Встановлення залежностей <<<"
apt-get update
apt-get install -y --no-install-recommends \
    ca-certificates git curl wget make bc bison flex xz-utils file cpio \
    kmod perl build-essential libncurses-dev libssl-dev libelf-dev \
    gcc-arm-linux-gnueabihf qemu-system-arm

cd "$WORK/src"
clone() {
    local url=$1 dir=$2
    shift 2
    if [ ! -d "$dir/.git" ]; then
        rm -rf "$dir.tmp"
        git clone "$@" "$url" "$dir.tmp"
        mv "$dir.tmp" "$dir"
    fi
}

echo ">>> Клонування ядра та BusyBox <<<"
clone https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git \
      linux-stable --depth 1 --branch linux-4.19.y
clone https://git.busybox.net/busybox busybox --depth 1 --branch 1_31_stable

touch "$WORK/.setup_complete"
echo "Налаштування завершено."
