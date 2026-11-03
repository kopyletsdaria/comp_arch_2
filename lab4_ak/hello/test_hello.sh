#!/bin/sh

MOD=${MOD:-/lib/modules/$(uname -r)/extra/hello.ko}

run_case() {
	echo
	echo "=================================================="
	echo "### insmod hello.ko $*"
	dmesg -c > /dev/null
	insmod "$MOD" "$@"
	rc=$?
	echo "### exit code of insmod: $rc"
	if [ -r /sys/module/hello/parameters/count ]; then
		echo "### /sys/module/hello/parameters/count = $(cat /sys/module/hello/parameters/count)"
		echo "### rmmod hello"
		rmmod hello
		echo "### exit code of rmmod: $?"
	else
		echo "### module is not loaded (nothing to rmmod)"
	fi
	echo "### dmesg:"
	dmesg
}

echo "### modinfo hello"
modinfo hello

run_case                
run_case count=0        
run_case count=3        
run_case count=7       
run_case count=10      
run_case count=11      
