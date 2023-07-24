#!/bin/bash

# Copyright 2023 Da Xue
# Creative Commons Attribution-ShareAlike 4.0 International

if [ "$USER" != "root" ]; then
	echo "Please run as root." >&2
	exit 1
fi

LPT_DURATION=${1:-10}
echo "TEST DURATION:	$LPT_DURATION"
if [ -z "$LPT_IP" ]; then
	echo "LPT_IP not set." >&2
	LPT_IP=$(ip -4 route | grep default | head -n 1 | cut -d " " -f 3)
	if [ -z "$LPT_IP" ]; then
		exit 1
	fi
fi
echo "NET TEST IP:	$LPT_IP"

LPT_dd(){
	timeout -s INT ${LPT_DURATION} dd if=/dev/$1 of=/dev/null bs=1M iflag=nocache 2>&1 | tail -n 1 | cut -d " " -f 10
}

LPT_mdd(){
	pids=()
	output=$(mktemp)
	while [ ! -z "$1" ]; do
		timeout -s INT ${LPT_DURATION} dd if=/dev/$1 of=/dev/null bs=1M iflag=nocache 2>&1 | tail -n 1 | cut -d " " -f 10 >> $output &
		pids+=($!)
		shift
	done
	wait
	awk '{sum+=$1} END {print sum}' $output
	rm $output
}

time=$LPT_DURATION
ip=$LPT_IP
cpu_c=$(nproc --all)

vendor_path=/sys/class/dmi/id/board_vendor
if [ -e "$vendor_path" ]; then
	echo "BOARD VENDOR:	$(cat $vendor_path)"
fi
board_path=/sys/class/dmi/id/board_name
if [ -e "$board_path" ]; then
	echo "BOARD NAME:	$(cat $board_path)"
fi
cpu_st=$(stress-ng --matrix 1 -t ${time} --metrics-brief 2>&1 | tail -n 1 | tr -s " " | cut -d " " -f 9)
echo "CPU:ST		$cpu_st"
cpu_mt=$(stress-ng --matrix 0 -t ${time} --metrics-brief 2>&1 | tail -n 1 | tr -s " " | cut -d " " -f 9)
echo "CPU:MT($cpu_c)	$cpu_mt"
crypto_st=$(openssl speed -mr -bytes +4096 -seconds +${time} -evp aes-128-gcm 2> /dev/null | grep "^+F" | cut -d ":" -f 4)
echo "CRYPTO:ST	$crypto_st"
crypto_mt=$(openssl speed -multi $cpu_c -mr -bytes +4096 -seconds +${time} -evp aes-128-gcm 2> /dev/null | grep "^+F" | cut -d ":" -f 4)
echo "CRYPTO:MT($cpu_c)	$crypto_mt"
bw_st=$(stress-ng --memrate 1 -t ${time}s -M 2>&1 | grep -v stress-ng-memrate | grep write1024 | tr -s " " | cut -d " " -f 5)
echo "MEM_BW:ST	$bw_st"
bw_mt=$(stress-ng --memrate 0 -t ${time}s -M 2>&1 | grep -v stress-ng-memrate | grep write1024 | tr -s " " | cut -d " " -f 5 | sed "s/$/*$cpu_c/" | bc)
echo "MEM_BW:MT($cpu_c)	$bw_mt"
mmc0=$(timeout -s INT ${time} dd if=/dev/mmcblk0 of=/dev/null bs=1M iflag=nocache 2>&1 | tail -n 1 | cut -d " " -f 10)
if [ -b "/dev/mmcblk1" ]; then
	echo "EMMC:		$mmc0"
	mmc1=$(timeout -s INT ${time} dd if=/dev/mmcblk1 of=/dev/null bs=1M iflag=nocache 2>&1 | tail -n 1 | cut -d " " -f 10)
	echo "SD:		$mmc1"
else
	echo "SD:		$mmc0"
fi
net_hd=$(iperf -c ${ip} -f M --sum-only -t ${time} | tail -n 1 | tr -s " " | cut -d " " -f 6)
echo "NET:HD		$net_hd"
net_fd=$(iperf -c ${ip} -f M --sum-only -t ${time} -d | tail -n 1 | tr -s " " | cut -d " " -f 6)
echo "NET:FD		$net_fd"
usb_st=$(LPT_dd $(lsblk -nld | grep ^sd | cut -d " " -f 1 | head -n 1))
echo "USB:ST		$usb_st"
usb_c=$(lsblk -nld | grep ^sd | cut -d " " -f 1 | wc -l)
usb_mt=$(LPT_mdd $(lsblk -nld | grep ^sd | cut -d " " -f 1))
echo "USB:MT($usb_c)	$usb_mt"

