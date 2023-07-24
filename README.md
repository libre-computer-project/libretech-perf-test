# libretech-perf-test

## purpose
quickly test performance of a libre computer board

## instructions
```
git clone https://github.com/libre-computer-project/libretech-perf-test.git
cd libretech-perf-test
./setup.sh
sudo LPT_IP=192.168.0.1 ./run.sh
BOARD VENDOR:	libre-computer
BOARD NAME:  all-h3-cc-h5
TEST DURATION:	10
NET TEST IP:	192.168.1.2
CPU:ST		230.56
CPU:MT(4)	638.07
CRYPTO:ST	469201113.74
CRYPTO:MT(4)	1859297543.64
MEM_BW:ST	3406.61
MEM_BW:MT(4)	4026.88
EMMC:		84.6
SD:		17.5
NET:HD		5.86
NET:FD		19.8
USB:ST		30.4
USB:MT(4)	94.7
```

## variables
LPT_DURATION the first parameter of run.sh that sets the test duration which should not affect scores unless it is too short
LPT_IP the IP running iperf for network test
