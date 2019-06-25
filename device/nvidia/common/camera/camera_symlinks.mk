# Copyright (c) 2016-2018, NVIDIA CORPORATION.  All rights reserved.
#
# NVIDIA CORPORATION and its licensors retain all intellectual property
# and proprietary rights in and to this software, related documentation
# and any modifications thereto.  Any use, reproduction, disclosure or
# distribution of this software and related documentation without an express
# license agreement from NVIDIA CORPORATION is strictly prohibited.

#
# Camera symlink creator
#
LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)

LOCAL_MODULE         := camera.autofocus.symlink
LOCAL_MODULE_CLASS   := FAKE
LOCAL_MODULE_TAGS    := optional
LOCAL_MODULE_PATH    := $(TARGET_OUT)/etc/permissions

PRIVATE_CAM_SYMLINK := /data/camera_config/etc/permissions/android.hardware.camera.autofocus.xml
PRIVATE_SYMLINK := $(TARGET_OUT)/etc/permissions/android.hardware.camera.autofocus.xml

LOCAL_POST_INSTALL_CMD := \
    rm -rf $(LOCAL_MODULE_PATH)/$(LOCAL_MODULE); \
    ln -sf $(PRIVATE_CAM_SYMLINK) $(PRIVATE_SYMLINK)

include $(BUILD_SYSTEM)/base_rules.mk

$(LOCAL_BUILT_MODULE):
	@echo "Symlink: $(PRIVATE_SYMLINK) -> $(PRIVATE_CAM_SYMLINK)"
	$(hide) mkdir -p $(dir $@)
	$(hide) rm -rf $@
	$(hide) touch $@

include $(CLEAR_VARS)

LOCAL_MODULE         := camera.external.symlink
LOCAL_MODULE_CLASS   := FAKE
LOCAL_MODULE_TAGS    := optional
LOCAL_MODULE_PATH    := $(TARGET_OUT)/etc/permissions

PRIVATE_CAM_SYMLINK := /data/camera_config/etc/permissions/android.hardware.camera.external.xml
PRIVATE_SYMLINK := $(TARGET_OUT)/etc/permissions/android.hardware.camera.external.xml

LOCAL_POST_INSTALL_CMD := \
    rm -rf $(LOCAL_MODULE_PATH)/$(LOCAL_MODULE); \
    ln -sf $(PRIVATE_CAM_SYMLINK) $(PRIVATE_SYMLINK)

include $(BUILD_SYSTEM)/base_rules.mk

$(LOCAL_BUILT_MODULE):
	@echo "Symlink: $(PRIVATE_SYMLINK) -> $(PRIVATE_CAM_SYMLINK)"
	$(hide) mkdir -p $(dir $@)
	$(hide) rm -rf $@
	$(hide) touch $@

include $(CLEAR_VARS)

LOCAL_MODULE         := camera.flash-autofocus.symlink
LOCAL_MODULE_CLASS   := FAKE
LOCAL_MODULE_TAGS    := optional
LOCAL_MODULE_PATH    := $(TARGET_OUT)/etc/permissions

PRIVATE_CAM_SYMLINK := /data/camera_config/etc/permissions/android.hardware.camera.flash-autofocus.xml
PRIVATE_SYMLINK := $(TARGET_OUT)/etc/permissions/android.hardware.camera.flash-autofocus.xml

LOCAL_POST_INSTALL_CMD := \
    rm -rf $(LOCAL_MODULE_PATH)/$(LOCAL_MODULE); \
    ln -sf $(PRIVATE_CAM_SYMLINK) $(PRIVATE_SYMLINK)

include $(BUILD_SYSTEM)/base_rules.mk

$(LOCAL_BUILT_MODULE):
	@echo "Symlink: $(PRIVATE_SYMLINK) -> $(PRIVATE_CAM_SYMLINK)"
	$(hide) mkdir -p $(dir $@)
	$(hide) rm -rf $@
	$(hide) touch $@

include $(CLEAR_VARS)

LOCAL_MODULE         := camera.front.symlink
LOCAL_MODULE_CLASS   := FAKE
LOCAL_MODULE_TAGS    := optional
LOCAL_MODULE_PATH    := $(TARGET_OUT)/etc/permissions

PRIVATE_CAM_SYMLINK := /data/camera_config/etc/permissions/android.hardware.camera.front.xml
PRIVATE_SYMLINK := $(TARGET_OUT)/etc/permissions/android.hardware.camera.front.xml

LOCAL_POST_INSTALL_CMD := \
    rm -rf $(LOCAL_MODULE_PATH)/$(LOCAL_MODULE); \
    ln -sf $(PRIVATE_CAM_SYMLINK) $(PRIVATE_SYMLINK)

include $(BUILD_SYSTEM)/base_rules.mk

$(LOCAL_BUILT_MODULE):
	@echo "Symlink: $(PRIVATE_SYMLINK) -> $(PRIVATE_CAM_SYMLINK)"
	$(hide) mkdir -p $(dir $@)
	$(hide) rm -rf $@
	$(hide) touch $@

include $(CLEAR_VARS)

LOCAL_MODULE         := camera.full.symlink
LOCAL_MODULE_CLASS   := FAKE
LOCAL_MODULE_TAGS    := optional
LOCAL_MODULE_PATH    := $(TARGET_OUT)/etc/permissions

PRIVATE_CAM_SYMLINK := /data/camera_config/etc/permissions/android.hardware.camera.full.xml
PRIVATE_SYMLINK := $(TARGET_OUT)/etc/permissions/android.hardware.camera.full.xml

LOCAL_POST_INSTALL_CMD := \
    rm -rf $(LOCAL_MODULE_PATH)/$(LOCAL_MODULE); \
    ln -sf $(PRIVATE_CAM_SYMLINK) $(PRIVATE_SYMLINK)

include $(BUILD_SYSTEM)/base_rules.mk

$(LOCAL_BUILT_MODULE):
	@echo "Symlink: $(PRIVATE_SYMLINK) -> $(PRIVATE_CAM_SYMLINK)"
	$(hide) mkdir -p $(dir $@)
	$(hide) rm -rf $@
	$(hide) touch $@

include $(CLEAR_VARS)

LOCAL_MODULE         := camera.manual_sensor.symlink
LOCAL_MODULE_CLASS   := FAKE
LOCAL_MODULE_TAGS    := optional
LOCAL_MODULE_PATH    := $(TARGET_OUT)/etc/permissions

PRIVATE_CAM_SYMLINK := /data/camera_config/etc/permissions/android.hardware.camera.manual_sensor.xml
PRIVATE_SYMLINK := $(TARGET_OUT)/etc/permissions/android.hardware.camera.manual_sensor.xml

LOCAL_POST_INSTALL_CMD := \
    rm -rf $(LOCAL_MODULE_PATH)/$(LOCAL_MODULE); \
    ln -sf $(PRIVATE_CAM_SYMLINK) $(PRIVATE_SYMLINK)

include $(BUILD_SYSTEM)/base_rules.mk

$(LOCAL_BUILT_MODULE):
	@echo "Symlink: $(PRIVATE_SYMLINK) -> $(PRIVATE_CAM_SYMLINK)"
	$(hide) mkdir -p $(dir $@)
	$(hide) rm -rf $@
	$(hide) touch $@

include $(CLEAR_VARS)

LOCAL_MODULE         := camera.manual_postprocessing.symlink
LOCAL_MODULE_CLASS   := FAKE
LOCAL_MODULE_TAGS    := optional
LOCAL_MODULE_PATH    := $(TARGET_OUT)/etc/permissions

PRIVATE_CAM_SYMLINK := /data/camera_config/etc/permissions/android.hardware.camera.manual_postprocessing.xml
PRIVATE_SYMLINK := $(TARGET_OUT)/etc/permissions/android.hardware.camera.manual_postprocessing.xml

LOCAL_POST_INSTALL_CMD := \
    rm -rf $(LOCAL_MODULE_PATH)/$(LOCAL_MODULE); \
    ln -sf $(PRIVATE_CAM_SYMLINK) $(PRIVATE_SYMLINK)

include $(BUILD_SYSTEM)/base_rules.mk

$(LOCAL_BUILT_MODULE):
	@echo "Symlink: $(PRIVATE_SYMLINK) -> $(PRIVATE_CAM_SYMLINK)"
	$(hide) mkdir -p $(dir $@)
	$(hide) rm -rf $@
	$(hide) touch $@

include $(CLEAR_VARS)

LOCAL_MODULE         := camera.raw.symlink
LOCAL_MODULE_CLASS   := FAKE
LOCAL_MODULE_TAGS    := optional
LOCAL_MODULE_PATH    := $(TARGET_OUT)/etc/permissions

PRIVATE_CAM_SYMLINK := /data/camera_config/etc/permissions/android.hardware.camera.raw.xml
PRIVATE_SYMLINK := $(TARGET_OUT)/etc/permissions/android.hardware.camera.raw.xml

LOCAL_POST_INSTALL_CMD := \
    rm -rf $(LOCAL_MODULE_PATH)/$(LOCAL_MODULE); \
    ln -sf $(PRIVATE_CAM_SYMLINK) $(PRIVATE_SYMLINK)

include $(BUILD_SYSTEM)/base_rules.mk

$(LOCAL_BUILT_MODULE):
	@echo "Symlink: $(PRIVATE_SYMLINK) -> $(PRIVATE_CAM_SYMLINK)"
	$(hide) mkdir -p $(dir $@)
	$(hide) rm -rf $@
	$(hide) touch $@

include $(CLEAR_VARS)

LOCAL_MODULE         := camera.symlink
LOCAL_MODULE_CLASS   := FAKE
LOCAL_MODULE_TAGS    := optional
LOCAL_MODULE_PATH    := $(TARGET_OUT)/etc/permissions

PRIVATE_CAM_SYMLINK := /data/camera_config/etc/permissions/android.hardware.camera.xml
PRIVATE_SYMLINK := $(TARGET_OUT)/etc/permissions/android.hardware.camera.xml

LOCAL_POST_INSTALL_CMD := \
    rm -rf $(LOCAL_MODULE_PATH)/$(LOCAL_MODULE); \
    ln -sf $(PRIVATE_CAM_SYMLINK) $(PRIVATE_SYMLINK)

include $(BUILD_SYSTEM)/base_rules.mk

$(LOCAL_BUILT_MODULE):
	@echo "Symlink: $(PRIVATE_SYMLINK) -> $(PRIVATE_CAM_SYMLINK)"
	$(hide) mkdir -p $(dir $@)
	$(hide) rm -rf $@
	$(hide) touch $@

# media profiles
include $(CLEAR_VARS)

LOCAL_MODULE         := camera.media.symlink
LOCAL_MODULE_CLASS   := FAKE
LOCAL_MODULE_TAGS    := optional
LOCAL_MODULE_PATH    := $(TARGET_OUT)/etc

PRIVATE_CAM_SYMLINK := /data/camera_config/etc/media_profiles.xml
PRIVATE_SYMLINK := $(TARGET_OUT)/etc/media_profiles.xml

LOCAL_POST_INSTALL_CMD := \
    rm -rf $(LOCAL_MODULE_PATH)/$(LOCAL_MODULE); \
    ln -sf $(PRIVATE_CAM_SYMLINK) $(PRIVATE_SYMLINK)

include $(BUILD_SYSTEM)/base_rules.mk

$(LOCAL_BUILT_MODULE):
	@echo "Symlink: $(PRIVATE_SYMLINK) -> $(PRIVATE_CAM_SYMLINK)"
	$(hide) mkdir -p $(dir $@)
	$(hide) rm -rf $@
	$(hide) touch $@

# WAR for NvCamera on cust build
# create JNI lib softlink for NvCamera.

include $(CLEAR_VARS)

LOCAL_MODULE         := camera.jnilib1.symlink
LOCAL_MODULE_CLASS   := FAKE
LOCAL_MODULE_TAGS    := optional
LOCAL_MODULE_PATH    := $(TARGET_OUT_VENDOR)/app/NvCamera/lib/arm

PRIVATE_CAM_SYMLINK := /vendor/lib/libcom_nvidia_nvcamera_util_NativeUtils.so
PRIVATE_SYMLINK := $(TARGET_OUT_VENDOR)/app/NvCamera/lib/arm/libcom_nvidia_nvcamera_util_NativeUtils.so

LOCAL_POST_INSTALL_CMD := \
    rm -rf $(LOCAL_MODULE_PATH)/$(LOCAL_MODULE); \
    ln -sf $(PRIVATE_CAM_SYMLINK) $(PRIVATE_SYMLINK)

include $(BUILD_SYSTEM)/base_rules.mk

$(LOCAL_BUILT_MODULE):
	@echo "Symlink: $(PRIVATE_SYMLINK) -> $(PRIVATE_CAM_SYMLINK)"
	$(hide) mkdir -p $(dir $@)
	$(hide) rm -rf $@
	$(hide) touch $@

include $(CLEAR_VARS)

LOCAL_MODULE         := camera.jnilib2.symlink
LOCAL_MODULE_CLASS   := FAKE
LOCAL_MODULE_TAGS    := optional
LOCAL_MODULE_PATH    := $(TARGET_OUT_VENDOR)/app/NvCamera/lib/arm

PRIVATE_CAM_SYMLINK := /vendor/lib/libjni_nvmosaic.so
PRIVATE_SYMLINK := $(TARGET_OUT_VENDOR)/app/NvCamera/lib/arm/libjni_nvmosaic.so

LOCAL_POST_INSTALL_CMD := \
    rm -rf $(LOCAL_MODULE_PATH)/$(LOCAL_MODULE); \
    ln -sf $(PRIVATE_CAM_SYMLINK) $(PRIVATE_SYMLINK)

include $(BUILD_SYSTEM)/base_rules.mk

$(LOCAL_BUILT_MODULE):
	@echo "Symlink: $(PRIVATE_SYMLINK) -> $(PRIVATE_CAM_SYMLINK)"
	$(hide) mkdir -p $(dir $@)
	$(hide) rm -rf $@
	$(hide) touch $@

include $(CLEAR_VARS)

LOCAL_MODULE         := camera.jnilib3.symlink
LOCAL_MODULE_CLASS   := FAKE
LOCAL_MODULE_TAGS    := optional
LOCAL_MODULE_PATH    := $(TARGET_OUT_VENDOR)/app/NvCamera/lib/arm

PRIVATE_CAM_SYMLINK := /vendor/lib/libnvjni_jpegutil.so
PRIVATE_SYMLINK := $(TARGET_OUT_VENDOR)/app/NvCamera/lib/arm/libnvjni_jpegutil.so

LOCAL_POST_INSTALL_CMD := \
    rm -rf $(LOCAL_MODULE_PATH)/$(LOCAL_MODULE); \
    ln -sf $(PRIVATE_CAM_SYMLINK) $(PRIVATE_SYMLINK)

include $(BUILD_SYSTEM)/base_rules.mk

$(LOCAL_BUILT_MODULE):
	@echo "Symlink: $(PRIVATE_SYMLINK) -> $(PRIVATE_CAM_SYMLINK)"
	$(hide) mkdir -p $(dir $@)
	$(hide) rm -rf $@
	$(hide) touch $@

include $(CLEAR_VARS)

LOCAL_MODULE         := camera.jnilib4.symlink
LOCAL_MODULE_CLASS   := FAKE
LOCAL_MODULE_TAGS    := optional
LOCAL_MODULE_PATH    := $(TARGET_OUT_VENDOR)/app/NvCamera/lib/arm

PRIVATE_CAM_SYMLINK := /vendor/lib/libnvjni_tinyplanet.so
PRIVATE_SYMLINK := $(TARGET_OUT_VENDOR)/app/NvCamera/lib/arm/libnvjni_tinyplanet.so

LOCAL_POST_INSTALL_CMD := \
    rm -rf $(LOCAL_MODULE_PATH)/$(LOCAL_MODULE); \
    ln -sf $(PRIVATE_CAM_SYMLINK) $(PRIVATE_SYMLINK)

include $(BUILD_SYSTEM)/base_rules.mk

$(LOCAL_BUILT_MODULE):
	@echo "Symlink: $(PRIVATE_SYMLINK) -> $(PRIVATE_CAM_SYMLINK)"
	$(hide) mkdir -p $(dir $@)
	$(hide) rm -rf $@
	$(hide) touch $@

include $(CLEAR_VARS)

LOCAL_MODULE         := camera.jnilib5.symlink
LOCAL_MODULE_CLASS   := FAKE
LOCAL_MODULE_TAGS    := optional
LOCAL_MODULE_PATH    := $(TARGET_OUT_VENDOR)/app/NvCamera/lib/arm

PRIVATE_CAM_SYMLINK := /vendor/lib/libnvraw_creator.so
PRIVATE_SYMLINK := $(TARGET_OUT_VENDOR)/app/NvCamera/lib/arm/libnvraw_creator.so

LOCAL_POST_INSTALL_CMD := \
    rm -rf $(LOCAL_MODULE_PATH)/$(LOCAL_MODULE); \
    ln -sf $(PRIVATE_CAM_SYMLINK) $(PRIVATE_SYMLINK)

include $(BUILD_SYSTEM)/base_rules.mk

$(LOCAL_BUILT_MODULE):
	@echo "Symlink: $(PRIVATE_SYMLINK) -> $(PRIVATE_CAM_SYMLINK)"
	$(hide) mkdir -p $(dir $@)
	$(hide) rm -rf $@
	$(hide) touch $@
