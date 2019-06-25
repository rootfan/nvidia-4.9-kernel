#!/vendor/bin/sh
#
# Copyright (c) 2015-2018 NVIDIA Corporation.  All rights reserved.
#
# NVIDIA Corporation and its licensors retain all intellectual property
# and proprietary rights in and to this software, related documentation
# and any modifications thereto.  Any use, reproduction, disclosure or
# distribution of this software and related documentation without an express
# license agreement from NVIDIA Corporation is strictly prohibited.
#

# Read the Board/Platform name
hardwareName=$(getprop ro.hardware)

# choose first udc
UDC_NAME=$(set -v `ls /sys/class/udc` && echo $1)
if [ -n "$UDC_NAME" ] && [ -e /sys/class/udc/$UDC_NAME ]; then
	setprop sys.usb.udc $UDC_NAME
	setprop sys.usb.controller $UDC_NAME
fi

# set sys.usb.configfs as 0 kernel 3.10 and 1 otherwise
setprop sys.usb.configfs 1
k310=$(cat /proc/version | grep "Linux version 3.10")
if [ "$k310" != "" ]; then
	setprop sys.usb.configfs 0
fi

# Enable ADB if the "safe mode w/ adb" DT node is present
usbPortPath=/sys/class/extcon/ID/connect
safeModeDTPath=/proc/device-tree/chosen/nvidia,safe_mode_adb

ls $safeModeDTPath

if [[ $? -eq 0 ]]; then # Safe Mode w/ ADB
	# Init the USB to "device" mode only for Darcy SKUs
	if [[ $hardwareName = *"darcy"* ]]; then
		echo "none" > $usbPortPath
	fi

	# Append adb to the usb config
	currConfig=$(getprop persist.sys.usb.config)
	if [[ $currConfig != *"adb"* ]]; then
		if [[ -z $currConfig ]]; then
			setprop sys.usb.config adb
		else
			setprop sys.usb.config $currConfig,adb
		fi
	fi
else # All other Modes
	# Init the USB to default mode only for Darcy SKUs
	if [[ $hardwareName = *"darcy"* ]]; then
		if [[ $(getprop persist.convertible.usb.mode) == "host" ]]; then
			echo "USB-HOST" > $usbPortPath
		fi
	fi

	# Assign the persistent USB config; if it exists
	currConfig=$(getprop persist.sys.usb.config)
	if [[ ! -z "$currConfig" ]]; then
		setprop sys.usb.config $currConfig
	fi
fi