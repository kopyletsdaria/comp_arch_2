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
    for c in "uname -a" "ls -l" "dmesg | grep init" "busybox --help | head -15" "poweroff"; do
        echo "$c"
        sleep 4
    done
    sleep 5
} | timeout 300 "${QEMU[@]}" 2>&1 | tr -d '\r' | tee "$LOGS/qemu_session.log" || true

echo "Журнал збережено: $LOGS/qemu_session.log"