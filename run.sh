#!/bin/bash

# Copyright 2023 Da Xue
# Creative Commons Attribution-ShareAlike 4.0 International

if [ "$USER" != "root" ]; then
	echo "Please run as root." >&2
	exit 1
fi

EXIT_runSetup(){
	echo "Please install $1 by running setup.sh." >&2
	exit 1
}

GLMARK2=glmark2-es2-drm
case "$(lsb_release -cs)" in
	bullseye)
		GLMARK2=
		;;
	buster)
		GLMARK2=
		;;
esac

for prereq in bc stress-ng iperf $GLMARK2; do
	if ! which $prereq > /dev/null; then
		EXIT_runSetup $prereq
	fi
done

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
	local throughput=$(timeout -s INT ${LPT_DURATION} dd if=/dev/$1 of=/dev/null bs=1M iflag=nocache 2>&1 | tail -n 1 | cut -d " " -f 10,11)
	if [ -z "$throughput" ]; then
		local throughput=0
	else
		local number=${throughput%% *}
		local suffix=${throughput##* }
		case "$suffix" in
			"GB/s")
				local throughput=$(echo "$number * 1024" | bc)
				;;
			"MB/s")
				local throughput=$number
				;;
			"KB/s")
				local throughput=$(echo "scale=3; $number / 1024" | bc)
				;;
			*)
				echo "$FUNC: unknown throughput from dd: $throughput" >&2
				local throughput=0
				;;
		esac
	fi
	echo "$throughput"
}

LPT_mdd(){
	pids=()
	output=$(mktemp)
	while [ ! -z "$1" ]; do
		LPT_dd $1 >> $output &
		pids+=($!)
		shift
	done
	wait
	awk '{sum+=$1} END {print sum}' $output
	rm $output
}

LPT_getMMCType(){
	local width_path=/sys/class/mmc_host/$1/device/of_node/bus-width
	if [ ! -e "$width_path" ]; then
		echo "MMC"
		return
	fi
	local width=$(od --endian=big -i -An "$width_path" | xargs)
	case "$width" in
		4)
			echo "SD"
			;;
		8)
			echo "eMMC"
			;;
		*)
			echo "$FUNC: unknown mmc type: $width" >&2
			echo "MMC"
			;;
	esac
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
cpu_st=$(stress-ng --matrix 1 -t ${time} --metrics-brief 2>&1 | grep matrix | grep -v instances | tail -n 1 | tr -s " " | cut -d " " -f 9)
echo "CPU:ST		$cpu_st"
cpu_mt=$(stress-ng --matrix 0 -t ${time} --metrics-brief 2>&1 | grep matrix | grep -v instances | tail -n 1 | tr -s " " | cut -d " " -f 9)
echo "CPU:MT($cpu_c)	$cpu_mt"
crypto_st=$(openssl speed -mr -bytes +4096 -seconds +${time} -evp aes-128-gcm 2> /dev/null | grep "^+F" | cut -d ":" -f 4 | sed "s/^/scale=3; /" | sed "s/\$/ \/ 1024 ^ 2/" | bc)
echo "CRYPTO:ST	$crypto_st"
crypto_mt=$(openssl speed -multi $cpu_c -mr -bytes +4096 -seconds +${time} -evp aes-128-gcm 2> /dev/null | grep "^+F" | cut -d ":" -f 4 | sed "s/^/scale=3; /" | sed "s/\$/ \/ 1024 ^ 2/" | bc)
echo "CRYPTO:MT($cpu_c)	$crypto_mt"
if [ ! -z "$GLMARK2" ]; then
	gpu_pixel=$(glmark2-es2-drm --benchmark refract:model=horse:duration=${time} --off-screen -s 1920x1920 | grep -o "Score: .*" | cut -d " " -f 2)
	echo "GPU:PIXEL	$gpu_pixel"
	gpu_vertex=$(glmark2-es2-drm --benchmark buffer:columns=1000:rows=30:duration=${time} --off-screen -s 1920x1920 | grep -o "Score: .*" | cut -d " " -f 2)
	echo "GPU:VERTEX	$gpu_vertex"
fi
bw_st=$(stress-ng --memrate 1 -t ${time}s -M 2>&1 | grep -v stress-ng-memrate | grep write1024 | tr -s " " | cut -d " " -f 5)
echo "MEM_BW:ST	$bw_st"
bw_mt=$(stress-ng --memrate 0 -t ${time}s -M 2>&1 | grep -v stress-ng-memrate | grep write1024 | tr -s " " | cut -d " " -f 5 | sed "s/$/*$cpu_c/" | bc)
echo "MEM_BW:MT($cpu_c)	$bw_mt"
if [ -b "/dev/mmcblk0" ]; then
	mmc0=$(LPT_dd mmcblk0)
	echo "$(LPT_getMMCType mmc0):		$mmc0"
fi
if [ -b "/dev/mmcblk1" ]; then
	mmc1=$(LPT_dd mmcblk1)
	echo "$(LPT_getMMCType mmc1):		$mmc1"
fi
sd_blks=$(lsblk -nld | grep ^sd | cut -d " " -f 1)
sd_blks_count=$(echo -n "$sd_blks" | wc -l)
if [ $sd_blks_count -gt 0 ]; then
	usb_st=$(LPT_dd $(echo "$sd_blks" | head -n 1))
	echo "USB:ST		$usb_st"
	usb_mt=$(LPT_mdd $sd_blks)
	echo "USB:MT($sd_blks_count)	$usb_mt"
fi
net_hd=$(iperf -c ${ip} -f M -P 2 --sum-only -t ${time} | tail -n 1 | tr -s " " | cut -d " " -f 6)
echo "NET:HD		$net_hd"
net_fd=$(iperf -c ${ip} -f M -P 2 --sum-only -t ${time} -d | tail -n 1 | tr -s " " | cut -d " " -f 6)
echo "NET:FD		$net_fd"
