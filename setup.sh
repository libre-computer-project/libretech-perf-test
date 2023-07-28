#!/bin/bash

SETUP_PREFIX=
if [ "$USER" != "root" ]; then
	if which sudo > /dev/null; then
		SETUP_PREFIX=sudo
	fi
fi

GLMARK2=glmark2-es2-drm
case "$(lsb_release -cs)" in
	bullseye)
		GLMARK2=
		;;
	buster)
		GLMARK2=
		;;
esac

$SETUP_PREFIX apt -y install stress-ng bc iperf mesa-utils $GLMARK2
