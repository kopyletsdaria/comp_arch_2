#!/bin/bash
set -euo pipefail

WORK=${WORK:-/work}
PROJECT=${PROJECT:-/project}
KDIR=$WORK/src/linux-stable         
BB=$WORK/src/busybox
ROOTFS=$WORK/rootfs_new
CORES=$(nproc)
MODE=${1:-build}

export ARCH=arm
export CROSS_COMPILE=arm-linux-gnueabihf-
export KDIR

mkdir -p "$PROJECT/logs"

run_qemu() {
    ${QEMU_TIMEOUT:-} qemu-system-arm -kernel "$KDIR/arch/arm/boot/zImage" \
        -initrd "$PROJECT/rootfs_new.cpio.gz" \
        -machine virt -nographic -m 512 \
        --append "root=/dev/ram0 rw console=ttyAMA0,115200 mem=512M $1"
}

if [ "$MODE" = "run" ]; then
    run_qemu ""
    exit 0
fi

echo ">>> 1. Ядро Linux 4.19 (потрібне для збірки модулів) <<<"
cd "$KDIR"
if [ ! -f arch/arm/boot/zImage ]; then
    mkdir -p fragments
    cat > fragments/bbb.cfg <<'CFG'
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
CFG
    ./scripts/kconfig/merge_config.sh arch/arm/configs/multi_v7_defconfig fragments/bbb.cfg
    make -j"$CORES" zImage modules am335x-boneblack.dtb
else
    echo "Ядро вже зібране, пропускаємо."
fi

echo ">>> 2. BusyBox 1.31 <<<"
cd "$BB"
if [ ! -x _install/bin/busybox ]; then
    make defconfig
    sed -i -e 's/^CONFIG_TC=y/# CONFIG_TC is not set/' \
           -e 's/^CONFIG_RDATE=y/# CONFIG_RDATE is not set/' \
           -e 's/^CONFIG_DATE=y/# CONFIG_DATE is not set/' .config
    (yes "" | make oldconfig > /dev/null 2>&1 || true)
    make -j"$CORES"
    make install
else
    echo "BusyBox вже зібраний, пропускаємо."
fi

echo ">>> 3. Перевірка стилю (checkpatch) <<<"
perl "$KDIR/scripts/checkpatch.pl" --no-tree -f "$PROJECT/hello/hello.c" \
    | tee "$PROJECT/logs/checkpatch.log" || true

echo ">>> 4. Збірка модуля hello.ko <<<"
make -C "$PROJECT/hello" clean
make -C "$PROJECT/hello" 2>&1 | tee "$PROJECT/logs/module_build.log"
file "$PROJECT/hello/hello.ko" | tee -a "$PROJECT/logs/module_build.log"
arm-linux-gnueabihf-readelf -p .modinfo "$PROJECT/hello/hello.ko" \
    | grep -E 'vermagic|parm' | tee -a "$PROJECT/logs/module_build.log" || true

echo ">>> 5. Формування rootfs_new <<<"
rm -rf "$ROOTFS"
cp -a "$BB/_install" "$ROOTFS"
mkdir -p "$ROOTFS"/{boot,dev,etc/init.d,lib/modules,proc,root,sys/kernel/debug,tmp}

cat > "$ROOTFS/etc/init.d/rcS" <<'RCS'
#!/bin/sh
mount -t sysfs none /sys
mount -t proc none /proc
mount -t debugfs none /sys/kernel/debug
echo /sbin/mdev > /proc/sys/kernel/hotplug
mdev -s
# режим автотесту: ядро запущене з параметром lab4test
if grep -q lab4test /proc/cmdline; then
    echo "===== LAB4 AUTOTEST START ====="
    /root/test_hello.sh
    echo "===== LAB4 AUTOTEST END ====="
    poweroff -f
fi
RCS
chmod +x "$ROOTFS/etc/init.d/rcS"
ln -sf bin/busybox "$ROOTFS/init"

cp "$KDIR/arch/arm/boot/zImage" "$KDIR/arch/arm/boot/dts/am335x-boneblack.dtb" \
   "$KDIR/System.map" "$ROOTFS/boot/"
cp "$KDIR/.config" "$ROOTFS/boot/config"
KVER=$(make -s -C "$KDIR" kernelrelease)
mkdir -p "$ROOTFS/lib/modules/$KVER/extra"
cp "$PROJECT/hello/hello.ko" "$ROOTFS/lib/modules/$KVER/extra/"
depmod -b "$ROOTFS" -F "$KDIR/System.map" "$KVER"
cp "$PROJECT/hello/test_hello.sh" "$ROOTFS/root/"
LIBDIR=$(dirname "$(arm-linux-gnueabihf-gcc -print-file-name=libc.so.6)")
for lib in ld-linux-armhf.so.3 libc.so.6 libm.so.6 libresolv.so.2 \
           libdl.so.2 libpthread.so.0 librt.so.1 libnss_files.so.2 libnss_dns.so.2; do
    [ -e "$LIBDIR/$lib" ] && cp -aL "$LIBDIR/$lib" "$ROOTFS/lib/"
done

echo '$MODALIAS=.* root:root 660 @modprobe "$MODALIAS"' > "$ROOTFS/etc/mdev.conf"
echo 'root:x:0:' > "$ROOTFS/etc/group"
echo 'root:x:0:0:root:/root:/bin/sh' > "$ROOTFS/etc/passwd"
echo 'root::10933:0:99999:7:::' > "$ROOTFS/etc/shadow"
echo "nameserver 8.8.8.8" > "$ROOTFS/etc/resolv.conf"

(cd "$ROOTFS" && find . | cpio -o -H newc 2>/dev/null | gzip > "$PROJECT/rootfs_new.cpio.gz")
ls -lh "$PROJECT/rootfs_new.cpio.gz"

if [ "$MODE" = "test" ]; then
    echo ">>> 6. Автотест у QEMU <<<"
    QEMU_TIMEOUT="timeout 300" run_qemu lab4test < /dev/null 2>&1 | tr -d '\r' | tee "$PROJECT/logs/qemu_test.log" || true
fi

echo "Готово. Інтерактивний запуск: bash build.sh run"
