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
GLMARK2_PRQ=$GLMARK2
case "$(lsb_release -cs)" in
	bullseye)
		GLMARK2_PRQ=
		;;
	buster)
		GLMARK2_PRQ=
		;;
esac

for prereq in bc stress-ng iperf $GLMARK2_PRQ; do
	if ! which $prereq > /dev/null; then
		EXIT_runSetup $prereq
	fi
done

LPT_DURATION=${1:-10}
echo "TEST DURATION:	$LPT_DURATION"

if [ -z "$LPT_IP_ETH" ]; then
	if [ ! -z "$LPT_IP" ]; then
		LPT_IP_ETH=$LPT_IP
	else
		echo "LPT_IP_ETH not set." >&2
	fi
fi
if [ -z "$LPT_IP_WIFI" ]; then
	if [ ! -z "$LPT_IP" ]; then
		LPT_IP_WIFI=$LPT_IP
	else
		echo "LPT_IP_WIFI not set." >&2
	fi
fi

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

LPT_runIPerf(){
	local duplex=""
	if [ $2 -eq 1 ]; then
		local duplex="-d"
	fi
	iperf -c "$1" -B "$3" -f M -P 2 --sum-only -t ${LPT_DURATION} $duplex | tail -n 1 | tr -s " " | cut -d " " -f 6
}

LPT_testIPerf(){
	local if_alias=$1
	shift
	local ip_target=$1
	shift
	for if_name in "$@"; do
		local if_ip=$(LPT_getIFIP $if_name)
		if [ ! -z "$if_ip" ]; then
			if [ "$if_alias" != "WIFI" ]; then
				local if_hd=$(LPT_runIPerf $ip_target 0 $if_ip)
				echo "$if_alias:HD		$if_hd"
			fi
			local if_fd=$(LPT_runIPerf $ip_target 1 $if_ip)
			echo "$if_alias:FD		$if_fd"
		fi
	done
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

LPT_getIFEth(){
	for interface in /sys/class/net/*; do
		if [ $(cat $interface/type) -eq 1 ]; then
			if [ ! -e $interface/wireless ]; then
				echo ${interface##*/}
			fi
		fi
	done
}

LPT_getIFWiFi(){
	for interface in /sys/class/net/*; do
		if [ $(cat $interface/type) -eq 1 ]; then
			if [ -e $interface/wireless ]; then
				echo ${interface##*/}
			fi
		fi
	done
}

LPT_getIFIP(){
	ip -4 addr show dev "$1" | grep "^\s*inet" | head -n 1 | tr -s " " | cut -d " " -f 3 | cut -d "/" -f 1
}

time=$LPT_DURATION
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
if which $GLMARK2 > /dev/null; then
	gpu_pixel=$($GLMARK2 --benchmark refract:model=horse:duration=${time} --off-screen -s 1920x1920 | grep -o "Score: .*" | cut -d " " -f 2)
	echo "GPU:PIXEL	$gpu_pixel"
	gpu_vertex=$($GLMARK2 --benchmark buffer:columns=1000:rows=30:duration=${time} --off-screen -s 1920x1920 | grep -o "Score: .*" | cut -d " " -f 2)
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
if [ ! -z "$LPT_IP_ETH" ]; then
	LPT_testIPerf ETH $LPT_IP_ETH $(LPT_getIFEth)
fi

#HACK currently it assumes ETH and WIFI are on same subnet
#TODO add subnet detection and overlap detection
if [ ! -z "$LPT_IP_WIFI" ]; then
	if [ "$LPT_IP_ETH" = "$LPT_IP_WIFI" ]; then
		eth=$(LPT_getIFEth)
		eth_down=()
		for i in $eth; do
			eth_ip=$(LPT_getIFIP "$eth")
			if [ ! -z "$eth_ip" ]; then
				ip link set dev $eth down
				eth_down+=($eth)
			fi
		done
	fi
	LPT_testIPerf WIFI $LPT_IP_WIFI $(LPT_getIFWiFi)
	if [ "$LPT_IP_ETH" = "$LPT_IP_WIFI" ]; then
		if [ ! -z "$eth_ip" ]; then
			for eth in ${eth_down[@]}; do
				ip link set dev $eth up
			done
		fi
	fi
fi
