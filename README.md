# libretech-perf-test

## purpose
quickly test performance of a libre computer board, see [results](https://docs.google.com/spreadsheets/d/1dlUla9b1TVcf-fjBOEwe3ojz5zhT3l3TJv7XnAYsLz8/edit?usp=sharing).

## instructions
```
$ git clone https://github.com/libre-computer-project/libretech-perf-test.git
$ cd libretech-perf-test
$ ./setup.sh
$ sudo LPT_IP=192.168.0.1 ./run.sh
BOARD VENDOR:	libre-computer
BOARD NAME:  	all-h3-cc-h5
TEST DURATION:	10
NET TEST IP:	192.168.0.1
CPU:ST		232.07
CPU:MT(4)	649.94
CRYPTO:ST	447.703
CRYPTO:MT(4)	1722.098
MEM_BW:ST	3407.51
MEM_BW:MT(4)	3723.80
EMMC:		84.6
SD:		18.7
NET:HD		5.40
NET:FD		18.1
USB:ST		30.7
USB:MT(4)	95.1
```

## variables
* LPT_DURATION the first parameter of run.sh that sets the test duration which should not affect scores unless it is too short
* LPT_IP the IP running iperf for network test

## Raspberry Pi 3 Model B+ vs Libre Computer AML-S905X-CC Le Potato
![Raspberry Pi 3 B+ vs AML-S905X-CC](compare/pi-3-b-plus-vs-aml-s905x-cc.png)
