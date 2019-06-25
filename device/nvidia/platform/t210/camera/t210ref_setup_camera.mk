# Copyright (c) 2018, NVIDIA CORPORATION.  All rights reserved.

# Please see
#   https://confluence.nvidia.com/display/CHI/Boot+Time+Camera+Configuration
# for more information.

# Setup camera-related definitions which enable boot time camera detection and populate camera features and media profiles.
include device/nvidia/common/camera/setup_camera.mk
# Setup v4l2 modules.
include device/nvidia/common/camera/setup_camera_v4l2.mk

MY_CAMERA_CONFIG_PATH := device/nvidia/platform/t210/camera
MY_CAMERA_DEF_FILE := t210ref_cameras.def

# Copy camera module definition file that would be used by config_cameras.sh through
# init.tegra.camera.rc file.
PRODUCT_COPY_FILES += \
    $(MY_CAMERA_CONFIG_PATH)/$(MY_CAMERA_DEF_FILE):odm/etc/$(MY_CAMERA_DEF_FILE) \

# Set 'tegra.camera.defpath' property so that config_cameras.sh loads correct
# camera definition file.
PRODUCT_PROPERTY_OVERRIDES += tegra.camera.defpath=/odm/etc/$(MY_CAMERA_DEF_FILE)

# Copy t210's media profiles
# We don't care about NV_ANDROID_MULTIMEDIA_ENHANCEMENTS flag here:
#   Use 'ifeq ($(NV_ANDROID_MULTIMEDIA_ENHANCEMENTS),TRUE)'..'else'..'endif' statements to use specific
#   media profiles depending on NV_ANDROID_MULTIMEDIA_ENHANCEMENTS flag.
PRODUCT_COPY_FILES += \
    $(MY_CAMERA_CONFIG_PATH)/nocam_media_profiles.xml:odm/etc/camera_repo/nocam_media_profiles.xml \
    $(MY_CAMERA_CONFIG_PATH)/e3326_media_profiles.xml:odm/etc/camera_repo/e3326_media_profiles.xml \
    $(MY_CAMERA_CONFIG_PATH)/e3323_media_profiles.xml:odm/etc/camera_repo/e3323_media_profiles.xml \
    $(MY_CAMERA_CONFIG_PATH)/e3333_media_profiles.xml:odm/etc/camera_repo/e3333_media_profiles.xml \
    $(MY_CAMERA_CONFIG_PATH)/imx274_media_profiles.xml:odm/etc/camera_repo/imx274_media_profiles.xml \

MY_CAMERA_CONFIG_PATH :=
MY_CAMERA_DEF_FILE :=