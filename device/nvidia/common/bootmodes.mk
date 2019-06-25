# Copyright (c) 2017 NVIDIA Corporation.  All rights reserved.

# This file is for multiple boot modes support, which can be inherited for
# any product requiring this feature.
#
# System will import proper init_bootmode_$(ro.boot.bootmode).rc based on
# ro.boot.bootmode property for different boot modes
#
#     Supported boot modes
#     - boot to UI: silicon boards
#     - boot to shell: stop boot at shell for bringup
#     - pre-silicon: lightweight shell for pre-silicon boards

TARGET_PROVIDES_INIT_RC := true

PRODUCT_COPY_FILES += \
    system/core/rootdir/init.rc:root/init.base.rc \
    $(LOCAL_PATH)/init.rc:root/init.rc \
    $(LOCAL_PATH)/init.bootmode_ui.rc:root/init.bootmode_ui.rc \
    $(LOCAL_PATH)/init.bootmode_shell.rc:root/init.bootmode_shell.rc \
    $(LOCAL_PATH)/init.bootmode_pre_si.rc:root/init.bootmode_pre_si.rc
