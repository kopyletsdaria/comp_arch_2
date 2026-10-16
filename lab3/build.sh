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
   && PATH=$EABI:$PATH CROSS_COMPILE='ccache arm-eabi-' make am335x_boneblack_defconfig \
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
./scripts/kconfig/merge_config.sh arch/arm/configs/multi_v7_defconfig fragments/bbb.cfg
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
    ls -lh "$KERNEL/arch/arm/boot/zImage" "$KERNEL/arch/arm/boot/dts/am335x-boneblack.dtb" 2>&1 || true
    echo "== BusyBox =="
    file "$BB/_install/bin/busybox"
    "$GNU/arm-linux-gnueabihf-readelf" -d "$BB/_install/bin/busybox" | grep NEEDED || true
    echo "== Модулі ядра у rootfs =="
    ls "$BB/_install/lib/modules/" || true
    echo "== Вміст /boot у rootfs =="
    ls -lh "$BB/_install/boot/"
    echo "== Розмір rootfs =="
    du -sh "$BB/_install"
    ls -lh "$BB/rootfs.cpio.gz"
} 2>&1 | tee "$LOGS/artifacts.txt"

cp -f "$KERNEL/arch/arm/boot/zImage" "$KERNEL/arch/arm/boot/dts/am335x-boneblack.dtb" "$BB/rootfs.cpio.gz" "$OUT/"
cp -f "$SRC/u-boot/MLO" "$SRC/u-boot/u-boot.img" "$OUT/" 2>/dev/null || true

echo "Збірку завершено. Запуск QEMU: bash run_qemu.sh test"