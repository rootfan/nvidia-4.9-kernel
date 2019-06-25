# Copyright (c) 2015-2016, NVIDIA CORPORATION.  All rights reserved.
#
# NVIDIA CORPORATION and its licensors retain all intellectual property
# and proprietary rights in and to this software, related documentation
# and any modifications thereto.  Any use, reproduction, disclosure or
# distribution of this software and related documentation without an express
# license agreement from NVIDIA CORPORATION is strictly prohibited.

#
# GPS symlink creator
#
ifeq (t210,$(TARGET_TEGRA_VERSION))
LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)

LOCAL_MODULE         := gps.symlink
LOCAL_MODULE_CLASS   := FAKE
LOCAL_MODULE_TAGS    := optional
LOCAL_MODULE_PATH    := $(TARGET_OUT)/etc/permissions

PRIVATE_GPS_SYMLINK := /data/android.hardware.location.gps.xml
PRIVATE_SYMLINK := $(TARGET_OUT)/etc/permissions/android.hardware.location.gps.xml

LOCAL_POST_INSTALL_CMD := \
    rm -rf $(LOCAL_MODULE_PATH)/$(LOCAL_MODULE); \
    ln -sf $(PRIVATE_GPS_SYMLINK) $(PRIVATE_SYMLINK)

include $(BUILD_SYSTEM)/base_rules.mk

$(LOCAL_BUILT_MODULE):
	@echo "Symlink: $(PRIVATE_SYMLINK) -> $(PRIVATE_GPS_SYMLINK)"
	$(hide) mkdir -p $(dir $@)
	$(hide) rm -rf $@
	$(hide) touch $@

endif # ifeq (t210,$(TARGET_TEGRA_VERSION))
