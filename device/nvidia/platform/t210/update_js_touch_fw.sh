#!/vendor/bin/sh

# Copyright (c) 2014, NVIDIA CORPORATION.  All rights reserved.
# NVIDIA CORPORATION and its licensors retain all intellectual property
# and proprietary rights in and to this software, related documentation
# and any modifications thereto.  Any use, reproduction, disclosure or
# distribution of this software and related documentation without an express
# license agreement from NVIDIA CORPORATION is strictly prohibited.

# update_js_touch_fw.sh -- Updates joystick and touch button board firmwares

GPLOAD="/vendor/bin/gpload"
CTLOAD="/vendor/bin/ctload"
JS_FW="/vendor/firmware/js_firmware.bin"
CT_FW="/vendor/firmware/ct_firmware.bin"

# Install js firmware
$GPLOAD ${JS_FW}

sleep 1

# Install ct firmware
$CTLOAD ${CT_FW}
