# Copyright (c) 2018, NVIDIA CORPORATION.  All rights reserved.

# Please see
#   https://confluence.nvidia.com/display/CHI/Boot+Time+Camera+Configuration
# for more information.

# Copy init.tegra.camera.rc file to /odm/etc/init folder.
PRODUCT_COPY_FILES += \
    device/nvidia/common/camera/init.tegra.camera.rc:odm/etc/init/init.tegra.camera.rc

# Copy config_cameras.sh script that will be used in init.tegra.camera.rc at boot time.
PRODUCT_COPY_FILES += \
    device/nvidia/common/camera/config_cameras.sh:vendor/bin/config_cameras.sh

# Copy all possible feature xml files to /odm/etc/camera_repo/ folder so that it can be used by config_cameras.sh script at boot time.
PRODUCT_COPY_FILES += \
    frameworks/native/data/etc/android.hardware.camera.full.xml:odm/etc/camera_repo/android.hardware.camera.full.xml \
    frameworks/native/data/etc/android.hardware.camera.external.xml:odm/etc/camera_repo/android.hardware.camera.external.xml \
    frameworks/native/data/etc/android.hardware.camera.front.xml:odm/etc/camera_repo/android.hardware.camera.front.xml \
    frameworks/native/data/etc/android.hardware.camera.raw.xml:odm/etc/camera_repo/android.hardware.camera.raw.xml \
    frameworks/native/data/etc/android.hardware.camera.manual_sensor.xml:odm/etc/camera_repo/android.hardware.camera.manual_sensor.xml \
    frameworks/native/data/etc/android.hardware.camera.xml:odm/etc/camera_repo/android.hardware.camera.xml \
    frameworks/native/data/etc/android.hardware.camera.flash-autofocus.xml:odm/etc/camera_repo/android.hardware.camera.flash-autofocus.xml \
    frameworks/native/data/etc/android.hardware.camera.autofocus.xml:odm/etc/camera_repo/android.hardware.camera.autofocus.xml \
    frameworks/native/data/etc/android.hardware.camera.manual_postprocessing.xml:odm/etc/camera_repo/android.hardware.camera.manual_postprocessing.xml

# Camera symlinks for feature/media_profile xml files
PRODUCT_PACKAGES += \
    camera.autofocus.symlink \
    camera.external.symlink \
    camera.flash-autofocus.symlink \
    camera.front.symlink \
    camera.full.symlink \
    camera.manual_sensor.symlink \
    camera.manual_postprocessing.symlink \
    camera.raw.symlink \
    camera.symlink \
    camera.media.symlink
