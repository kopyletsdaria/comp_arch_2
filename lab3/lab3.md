# ЛАБОРАТОРНА РОБОТА №3

**Тема:** «Розвертання програмного забезпечення»

**Виконала:** студентка групи ІО-44 Копилець Дар'я

**Перевірив:** Каплунов А.В.

---

**Мета:** Робота з інструкцією "ВeagleBone Black: Platform Bring Up with Upstream Components", опрацьовування частини завдання "Збирання виконуваних файлів для ОС Linux для процесорів архітектури ARM."

**Завдання:** Розвернути програмне середовище, підготувати інструменти (Інструкція, Частина 1, "Pгeparing the Tools")

---

## Файли проєкту:
### 1. Підготовка ізольованого середовища (Docker): 

‘docker-compose.yml’:

```yaml
services:
  lab3-arm-env:
    image: ubuntu:20.04
    platform: linux/amd64
    container_name: lab3_Kopylets
    tty: true
    stdin_open: true
    privileged: true
    environment:
      DEBIAN_FRONTEND=noninteractive
    volumes:
      - .:/project
      - work:/work
    working_dir: /project
    command: ["sleep", "infinity"]
volumes:
  work:
```

### 2. Скрипт автоматичного встановлення залежностей: 

‘setup.sh’:

```yaml
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
ARM_URL=https://developer.arm.com/-/media/Files/downloads/gnu-a/8.3
2019.03/binrel 
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
    clone https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git 
linux-stable --depth 1 --branch linux-4.19.y 
    clone https://git.busybox.net/busybox busybox --depth 1 --branch 1_31_stable 
 
    echo "Підготовка U-Boot..." 
    cd u-boot 
    git am --abort 2>/dev/null || true 
    LAST_TAG=$(git tag | grep -v rc | sort -V | tail -n 1) 
    git checkout -f "$LAST_TAG" 
    if ! curl -fsSL https://patchwork.ozlabs.org/series/130450/mbox/ | git am; 
then 
        git am --abort 2>/dev/null || true 
        echo "Патч 130450 не застосовано до $LAST_TAG (для QEMU не критично)" 
    fi 
    cd "$WORK/src" 
 
    echo "Збереження звіту про середовище..." 
    { 
        echo "== host gcc ==";                  gcc --version | head -1 
        echo "== arm-eabi-gcc ==";              /opt/$EABI_DIR/bin/arm-eabi-gcc --version | head -1 
        echo "== arm-linux-gnueabihf-gcc ==";   /opt/$GNU_DIR/bin/arm-linux
gnueabihf-gcc --version | head -1 
        echo "== qemu ==";                      qemu-system-arm --version | head -1 
        echo "== U-Boot ==";                    git -C u-boot log -1 --format='%h 
%D' 
        echo "== Linux kernel ==";              git -C linux-stable log -1 -
format='%h %D' 
        echo "== BusyBox ==";                   git -C busybox log -1 -
format='%h %D' 
    } > "$LOGS/env_check.txt" 2>&1 
    cat "$LOGS/env_check.txt" 
} 
do_setup 2>&1 | tee -a "$LOGS/setup.log" 
touch "$WORK/.setup_complete" 
echo "Налаштування завершено." 
exec bash
```

### 3. Збірка програмного забезпечення:

‘build.sh’: 

```yaml
#!/bin/bash 
set -euo pipefail 
WORK=${WORK:-/work} 
PROJECT=${PROJECT:-/project} 
LOGS=$PROJECT/logs 
OUT=$PROJECT/out 
SRC=$WORK/src 
BB=$SRC/busybox 
KERNEL=$SRC/linux-stable 
EABI=/opt/gcc-arm-8.3-2019.03-x86_64-arm-eabi/bin 
GNU=/opt/gcc-arm-8.3-2019.03-x86_64-arm-linux-gnueabihf/bin 
CORES=$(nproc) 
mkdir -p "$LOGS" "$OUT" 
exec > >(tee "$LOGS/build.log") 2>&1 
 
export ARCH=arm 
 
echo ">>> Збірка U-Boot <<<" 
if cd "$SRC/u-boot" \ 
   && PATH=$EABI:$PATH CROSS_COMPILE='ccache arm-eabi-' make 
am335x_boneblack_defconfig \ 
   && PATH=$EABI:$PATH CROSS_COMPILE='ccache arm-eabi-' make -j"$CORES"; then 
    echo "U-Boot: збірка успішна" 
else 
    echo "U-Boot не зібрався (для запуску в QEMU не критично)" 
fi 
cd "$WORK" 
 
echo ">>> Збірка Linux Kernel <<<" 
( 
export PATH=$EABI:$PATH 
export CROSS_COMPILE='ccache arm-eabi-' 
cd "$KERNEL" 
mkdir -p fragments 
cat > fragments/bbb.cfg <<'EOF' 
CONFIG_USB_ANNOUNCE_NEW_DEVICES=y 
CONFIG_USB_EHCI_ROOT_HUB_TT=y 
CONFIG_AM335X_PHY_USB=y 
CONFIG_USB_MUSB_TUSB6010=y 
CONFIG_USB_MUSB_OMAP2PLUS=y 
CONFIG_USB_MUSB_HDRC=y 
CONFIG_USB_MUSB_DSPS=y 
CONFIG_USB_MUSB_AM35X=y 
CONFIG_USB_CONFIGFS=y 
CONFIG_NOP_USB_XCEIV=y 
CONFIG_USB_HID=y 
CONFIG_USB_HIDDEV=y 
CONFIG_USB_SERIAL=y 
CONFIG_USB_SERIAL_PL2303=y 
CONFIG_USB_SERIAL_GENERIC=y 
CONFIG_USB_SERIAL_SIMPLE=y 
CONFIG_USB_SERIAL_FTDI_SIO=y 
CONFIG_USB_ULPI=y 
CONFIG_USB_ULPI_BUS=y 
CONFIG_BRIDGE=y 
CONFIG_OF_OVERLAY=y 
EOF 
./scripts/kconfig/merge_config.sh arch/arm/configs/multi_v7_defconfig 
fragments/bbb.cfg 
make HOSTCC=gcc-9 -j"$CORES" zImage modules am335x-boneblack.dtb 
) 
 
echo ">>> Збірка BusyBox <<<" 
( 
export PATH=$GNU:$PATH 
export CROSS_COMPILE='ccache arm-linux-gnueabihf-' 
cd "$BB" 
make defconfig 
make -j"$CORES" 
make install 
) 
 
echo ">>> Формування rootfs <<<" 
cd "$BB" 
mkdir -p _install/{boot,dev,etc/init.d,lib,proc,root,sys/kernel/debug,tmp} 
 
cat > _install/etc/init.d/rcS <<'EOF' 
#!/bin/sh 
mount -t sysfs none /sys 
mount -t proc none /proc 
mount -t debugfs none /sys/kernel/debug 
echo /sbin/mdev > /proc/sys/kernel/hotplug 
mdev -s 
EOF 
chmod +x _install/etc/init.d/rcS 
ln -sf bin/busybox _install/init 
 
cp "$KERNEL/arch/arm/boot/zImage" _install/boot/ 
cp "$KERNEL/arch/arm/boot/dts/am335x-boneblack.dtb" _install/boot/ 
cp "$KERNEL/System.map" _install/boot/ 
cp "$KERNEL/.config" _install/boot/config 
 
( 
export PATH=$EABI:$PATH 
export CROSS_COMPILE='ccache arm-eabi-' 
export INSTALL_MOD_PATH=$BB/_install 
cd "$KERNEL" 
make HOSTCC=gcc-9 modules_install 
) 
 
LIBC_DIR=$("$GNU/arm-linux-gnueabihf-gcc" -print-sysroot)/lib 
cp -a "$LIBC_DIR"/*.so* _install/lib/ 
 
echo '$MODALIAS=.* root:root 660 @modprobe "$MODALIAS"' > _install/etc/mdev.conf 
echo 'root:x:0:' > _install/etc/group 
echo 'root:x:0:0:root:/root:/bin/sh' > _install/etc/passwd 
echo 'root::10933:0:99999:7:::' > _install/etc/shadow 
echo "nameserver 8.8.8.8" > _install/etc/resolv.conf 
 
echo ">>> Пакування rootfs <<<" 
(cd _install && find . | cpio -o -H newc | gzip > ../rootfs.cpio.gz) 
 
echo ">>> Перевірка артефактів <<<" 
{ 
    echo "== U-Boot ==" 
    ls -lh "$SRC/u-boot/MLO" "$SRC/u-boot/u-boot.img" 2>&1 || true 
    echo "== Kernel ==" 
    ls -lh "$KERNEL/arch/arm/boot/zImage" "$KERNEL/arch/arm/boot/dts/am335x
boneblack.dtb" 2>&1 || true 
    echo "== BusyBox ==" 
    file "$BB/_install/bin/busybox" 
    "$GNU/arm-linux-gnueabihf-readelf" -d "$BB/_install/bin/busybox" | grep 
NEEDED || true 
    echo "== Модулі ядра у rootfs ==" 
    ls "$BB/_install/lib/modules/" || true 
    echo "== Вміст /boot у rootfs ==" 
    ls -lh "$BB/_install/boot/" 
    echo "== Розмір rootfs ==" 
    du -sh "$BB/_install" 
    ls -lh "$BB/rootfs.cpio.gz" 
} 2>&1 | tee "$LOGS/artifacts.txt" 
 
cp -f "$KERNEL/arch/arm/boot/zImage" "$KERNEL/arch/arm/boot/dts/am335x
boneblack.dtb" "$BB/rootfs.cpio.gz" "$OUT/" 
cp -f "$SRC/u-boot/MLO" "$SRC/u-boot/u-boot.img" "$OUT/" 2>/dev/null || true 
 
echo "Збірку завершено. Запуск QEMU: bash run_qemu.sh test" 
```

‘run_qemu.sh’: 

```yaml
#!/bin/bash 
# bash run_qemu.sh        - інтерактивний запуск  
# bash run_qemu.sh test   - автоматичний прогін команд  
set -euo pipefail 
 
WORK=${WORK:-/work} 
PROJECT=${PROJECT:-/project} 
LOGS=$PROJECT/logs 
BB=$WORK/src/busybox 
BOOT_WAIT=${BOOT_WAIT:-40} 
mkdir -p "$LOGS" 
QEMU=(qemu-system-arm 
      -kernel "$BB/_install/boot/zImage" 
      -initrd "$BB/rootfs.cpio.gz" 
      -machine virt -nographic -m 512 
      --append "root=/dev/ram0 rw console=ttyAMA0,115200 mem=512M") 
if [ "${1:-}" != "test" ]; then 
    exec "${QEMU[@]}" 
fi 
echo "Автотест QEMU (очікування завантаження ${BOOT_WAIT} с)..." 
{ 
    sleep "$BOOT_WAIT" 
    echo 
    sleep 3 
    for c in "uname -a" "ls -l" "dmesg | grep init" "busybox --help | head -15" 
"poweroff"; do 
        echo "$c" 
        sleep 4 
    done 
    sleep 5 
} | timeout 300 "${QEMU[@]}" 2>&1 | tr -d '\r' | tee "$LOGS/qemu_session.log" || 
true 
 
echo "Журнал збережено: $LOGS/qemu_session.log" 
```

### 4. Тестування в QEMU:


<img width="1046" height="1071" alt="image" src="https://github.com/user-attachments/assets/7461cb3a-4e81-4235-9062-07a77d316234" />


**Висновки:** Під час виконання лабораторної роботи було успішно розгорнуто ізольоване середовище для крос-компіляції під архітектуру ARM. Було зібрано завантажувач, ядро Linux та  кореневу файлову систему BusyBox. Також було проведено успішне тестування зібраної системи у  програмному емуляторі QEMU. 



