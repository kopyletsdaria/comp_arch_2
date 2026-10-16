#!/bin/bash
set -euo pipefail

WORK=${WORK:-/work}
PROJECT=${PROJECT:-/project}
LOGS=$PROJECT/logs
mkdir -p "$WORK/src" "$LOGS"

if [ -f "$WORK/.setup_complete" ]; then
    echo "Середовище вже налаштовано. Запуск bash..."
    exec bash
fi
EABI_DIR=gcc-arm-8.3-2019.03-x86_64-arm-eabi
GNU_DIR=gcc-arm-8.3-2019.03-x86_64-arm-linux-gnueabihf
ARM_URL=https://developer.arm.com/-/media/Files/downloads/gnu-a/8.3-2019.03/binrel
clone() {
    local url=$1 dir=$2
    shift 2
    if [ ! -d "$dir/.git" ]; then
        rm -rf "$dir.tmp"
        git clone "$@" "$url" "$dir.tmp"
        mv "$dir.tmp" "$dir"
    fi
}
get_toolchain() {
    local name=$1 f="$1.tar.xz" i
    [ -d "/opt/$name" ] && return 0
    for i in 1 2 3; do
        xz -t "$f" 2>/dev/null && break
        rm -f "$f"
        wget --tries=5 --retry-connrefused -O "$f" "$ARM_URL/$f" || true
    done
    xz -t "$f"
    tar xJf "$f" -C /opt/
}

do_setup() {
    export DEBIAN_FRONTEND=noninteractive
    echo "Оновлення системи та встановлення залежностей..."
    apt-get update
    apt-get install -y --no-install-recommends \
        ca-certificates git vim tree curl wget ccache make bc bison flex \
        xz-utils file bzip2 kmod cpio build-essential gcc-9 g++-9 \
        libncurses-dev libssl-dev libgnutls28-dev libmpc-dev libmpfr-dev \
        libgmp-dev uuid-dev python3 python3-dev python3-setuptools \
        python3-pyelftools swig qemu-system-arm

    echo "Налаштування GCC 9 за замовчуванням..."
    update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-9 100
    update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-9 100
    update-alternatives --set gcc /usr/bin/gcc-9
    update-alternatives --set g++ /usr/bin/g++-9

    git config --global user.name "Daria Kopylets"
    git config --global user.email "kopylets.daria_io_44@edu.kpi.ua"
    ccache -M 5G

    cd "$WORK/src"

    echo "Завантаження компіляторів ARM..."
    get_toolchain "$EABI_DIR"
    get_toolchain "$GNU_DIR"

    echo "Клонування репозиторіїв..."
    clone https://source.denx.de/u-boot/u-boot.git u-boot
    clone https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git linux-stable --depth 1 --branch linux-4.19.y
    clone https://git.busybox.net/busybox busybox --depth 1 --branch 1_31_stable

    echo "Підготовка U-Boot..."
    cd u-boot
    git am --abort 2>/dev/null || true
    LAST_TAG=$(git tag | grep -v rc | sort -V | tail -n 1)
    git checkout -f "$LAST_TAG"
    if ! curl -fsSL https://patchwork.ozlabs.org/series/130450/mbox/ | git am; then
        git am --abort 2>/dev/null || true
        echo "Патч 130450 не застосовано до $LAST_TAG (для QEMU не критично)"
    fi
    cd "$WORK/src"

    echo "Збереження звіту про середовище..."
    {
        echo "== host gcc ==";                  gcc --version | head -1
        echo "== arm-eabi-gcc ==";              /opt/$EABI_DIR/bin/arm-eabi-gcc --version | head -1
        echo "== arm-linux-gnueabihf-gcc ==";   /opt/$GNU_DIR/bin/arm-linux-gnueabihf-gcc --version | head -1
        echo "== qemu ==";                      qemu-system-arm --version | head -1
        echo "== U-Boot ==";                    git -C u-boot log -1 --format='%h %D'
        echo "== Linux kernel ==";              git -C linux-stable log -1 --format='%h %D'
        echo "== BusyBox ==";                   git -C busybox log -1 --format='%h %D'
    } > "$LOGS/env_check.txt" 2>&1
    cat "$LOGS/env_check.txt"
}
do_setup 2>&1 | tee -a "$LOGS/setup.log"
touch "$WORK/.setup_complete"
echo "Налаштування завершено."
exec bash