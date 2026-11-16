#!/bin/sh
EXT=/lib/modules/$(uname -r)/extra
ALL=/tmp/all_messages.log
: > "$ALL"

step() {
	echo
	echo "=================================================="
	echo "### $*"
}

show_dmesg() {
	echo "### dmesg -r:"
	dmesg -r | tee -a "$ALL"
	dmesg -c > /dev/null
}

show_param() {
	if [ -r /sys/module/hello2/parameters/count ]; then
		echo "### /sys/module/hello2/parameters/count = $(cat /sys/module/hello2/parameters/count)"
	fi
}

step "modinfo hello1"
modinfo hello1
step "modinfo hello2"
modinfo hello2

dmesg -c > /dev/null

# hello2 без hello1
step "insmod hello2.ko (hello1 НЕ завантажено)"
insmod $EXT/hello2.ko
echo "### exit code of insmod: $?"
show_dmesg

# hello1, потім hello2 з різними значеннями параметра
step "insmod hello1.ko"
insmod $EXT/hello1.ko
echo "### exit code of insmod: $?"
show_dmesg

for arg in "" "count=0" "count=3" "count=7" "count=11"; do
	step "insmod hello2.ko $arg"
	insmod $EXT/hello2.ko $arg
	echo "### exit code of insmod: $?"
	show_param
	if [ -d /sys/module/hello2 ]; then
		echo "### rmmod hello2"
		rmmod hello2
		echo "### exit code of rmmod: $?"
	fi
	show_dmesg
done

step "insmod hello2.ko count=2, потім спроба rmmod hello1 (поки hello2 завантажено)"
insmod $EXT/hello2.ko count=2
rmmod hello1
echo "### exit code of rmmod hello1: $?"
echo "### lsmod:"
lsmod
rmmod hello2
show_dmesg

step "rmmod hello1 (друк часу кожного виклику print_hello)"
rmmod hello1
echo "### exit code of rmmod: $?"
show_dmesg

step "Пошук повідомлень за рівнями (grep по накопиченому dmesg -r)"
echo "pr_err  (<3>):"; grep '^<3>' "$ALL"
echo "pr_warn (<4>):"; grep '^<4>' "$ALL"
echo "pr_info (<6>), перші 3 з: $(grep -c '^<6>' "$ALL") :"; grep '^<6>' "$ALL" | head -3
