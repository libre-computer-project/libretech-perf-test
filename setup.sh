#!/bin/bash

SETUP_PREFIX=
if [ "$USER" != "root" ]; then
	if which sudo > /dev/null; then
		SETUP_PREFIX=sudo
	fi
fi
$SETUP_PREFIX apt -y install stress-ng bc iperf glmark2-es2-drm mesa-utils
