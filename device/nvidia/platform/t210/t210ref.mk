# NVIDIA "T210ref" development system
#
# Copyright (c) 2013-2018 NVIDIA Corporation.  All rights reserved.

$(call inherit-product, device/nvidia/soc/t210/device-t210.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base.mk)
$(call inherit-product, device/nvidia/platform/t210/device.mk)
$(call inherit-product, device/nvidia/product/tablet/device.mk)

PRODUCT_NAME := t210ref
PRODUCT_DEVICE := t210
PRODUCT_MODEL := t210ref
PRODUCT_MANUFACTURER := NVIDIA
PRODUCT_BRAND := nvidia

ifeq ($(PLATFORM_IS_AFTER_M),)
HOST_PREFER_32_BIT := true
endif

TARGET_SYSTEM_PROP    += device/nvidia/platform/t210/t210ref.prop

# set default kernel to K4.9 if not set
KERNEL_PATH ?= $(CURDIR)/kernel/kernel-4.9

KERNEL_CONFIGFS_USB_GADGET := true

## Values of PRODUCT_NAME and PRODUCT_DEVICE are mangeled before it can be
## used because of call to inherits, store their values to
## use later in this file below
_product_name := $(strip $(PRODUCT_NAME))
_product_device := $(strip $(PRODUCT_DEVICE))

# for Jetpack APK
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/t210ref.vendor.libraries.android.txt:vendor/etc/public.libraries.txt

PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/../../common/init.cal.rc:root/init.cal.rc \
    $(LOCAL_PATH)/gpio-keys.kl:system/usr/keylayout/gpio-keys.kl \
    frameworks/native/data/etc/android.hardware.location.gps.xml:system/etc/android.hardware.location.gps.xml \
    frameworks/native/data/etc/android.software.midi.xml:system/etc/permissions/android.software.midi.xml \

PRODUCT_AAPT_CONFIG += xlarge large

ifeq ($(PLATFORM_IS_AFTER_LOLLIPOP),1)
## Verified_boot
$(call inherit-product,build/target/product/verity.mk)
PRODUCT_SYSTEM_VERITY_PARTITION := /dev/block/platform/sdhci-tegra.3/by-name/APP
PRODUCT_VENDOR_VERITY_PARTITION := /dev/block/platform/sdhci-tegra.3/by-name/vendor

PRODUCT_PACKAGES += \
    slideshow \
    verity_warning_images
PRODUCT_COPY_FILES += \
    frameworks/native/data/etc/android.software.verified_boot.xml:system/etc/permissions/android.software.verified_boot.xml
endif

################################################
# Common for all t210ref
################################################

# Include vendor HAL definitions
ifeq ($(PLATFORM_IS_AFTER_N),1)
include device/nvidia/platform/t210/t210refhal.mk
endif

PRODUCT_PACKAGES += \
        nfc.tegra \
        SoundRecorder

PRODUCT_COPY_FILES += \
    frameworks/native/data/etc/tablet_core_hardware.xml:system/etc/permissions/tablet_core_hardware.xml \
    frameworks/native/data/etc/android.hardware.touchscreen.multitouch.jazzhand.xml:system/etc/permissions/android.hardware.touchscreen.multitouch.jazzhand.xml \
    frameworks/native/data/etc/android.hardware.sensor.accelerometer.xml:system/etc/permissions/android.hardware.sensor.accelerometer.xml \
    frameworks/native/data/etc/android.hardware.sensor.compass.xml:system/etc/permissions/android.hardware.sensor.compass.xml \
    frameworks/native/data/etc/android.hardware.sensor.gyroscope.xml:system/etc/permissions/android.hardware.sensor.gyroscope.xml \
    frameworks/native/data/etc/android.hardware.sensor.barometer.xml:system/etc/permissions/android.hardware.sensor.barometer.xml \
    frameworks/native/data/etc/android.hardware.sensor.ambient_temperature.xml:system/etc/permissions/android.hardware.sensor.ambient_temperature.xml \
    frameworks/native/data/etc/android.hardware.sensor.light.xml:system/etc/permissions/android.hardware.sensor.light.xml \
    frameworks/native/data/etc/handheld_core_hardware.xml:system/etc/permissions/handheld_core_hardware.xml \
    $(LOCAL_PATH)/nvcamera.conf:system/etc/nvcamera.conf

# Camera Setup
## Setup camera-related definitions which enable boot time camera detection and populate camera features and media profiles for t210ref board
## Please see https://confluence.nvidia.com/display/CHI/Camera+Build+Configuration for more information.
include device/nvidia/platform/t210/camera/t210ref_setup_camera.mk

ifeq ($(NV_ANDROID_MULTIMEDIA_ENHANCEMENTS),TRUE)
PRODUCT_COPY_FILES += \
  $(LOCAL_PATH)/audio_policy.conf:system/etc/audio_policy.conf
else
PRODUCT_COPY_FILES += \
  $(LOCAL_PATH)/audio_policy_noenhance.conf:system/etc/audio_policy.conf
endif

PRODUCT_COPY_FILES += \
    device/nvidia/platform/t210/nvaudio_conf.xml:system/etc/nvaudio_conf.xml \
    device/nvidia/platform/t210/abca_nvaudio_conf.xml:system/etc/abca_nvaudio_conf.xml \
    device/nvidia/platform/t210/abca_nvaudio_conf.xml:system/etc/abcb_nvaudio_conf.xml

## SKU specific overrides
PRODUCT_PROPERTY_OVERRIDES += ro.radio.noril=true

## Tablet configuration
DEVICE_PACKAGE_OVERLAYS += device/nvidia/product/tablet/overlay-tablet/$(PLATFORM_VERSION_LETTER_CODE)

include device/nvidia/platform/t210/sensors-t210ref.mk
# The following build variables are defined in 'sensors-[platform].mk' file:
#	SENSOR_BUILD_VERSION
#	SENSOR_BUILD_FLAGS
#	SENSOR_FUSION_VENDOR
#	SENSOR_FUSION_VERSION
#	SENSOR_FUSION_BUILD_DIR
#	SENSOR_HAL_API
#	SENSOR_HAL_VERSION
#	SENSOR_HAL_HAL_OS_INTERFACE_SRC
#	SENSOR_HAL_LOCAL_DRIVER_SRC
#	PRODUCT_PROPERTY_OVERRIDES
#	PRODUCT_PACKAGES

# Sharp touch definitions
include device/nvidia/drivers/touchscreen/sharp/BoardConfigSharp.mk

ifeq ($(PLATFORM_VERSION_LETTER_CODE),n)
#Thermal HALs
PRODUCT_PACKAGES += \
    thermal.tegra
endif

# Launcher3
ifeq ($(PLATFORM_IS_AFTER_LOLLIPOP),1)
PRODUCT_PACKAGES += \
    Launcher3 \
    NvCustomize
endif

PRODUCT_PACKAGES += \
    rp3 \
    slideshow \
    verity_warning_images \
    libnvjni_tinyplanet \
    libnvjni_jpegutil \
    libcom_nvidia_nvcamera_util_NativeUtils \
    libjni_nvmosaic \
    libnvraw_creator

#symlinks
PRODUCT_PACKAGES += \
    camera.jnilib1.symlink \
    camera.jnilib2.symlink \
    camera.jnilib3.symlink \
    camera.jnilib4.symlink \
    camera.jnilib5.symlink

## Factory Reset Protection to be disabled in RP2 Partition
PRODUCT_COPY_FILES += device/nvidia/tegraflash/fac_rst_protection/disable_frp.bin:rp2.bin

## common apps for all skus
$(call inherit-product-if-exists, vendor/nvidia/$(_product_device)/skus/t210ref_variants_common.mk)

## nvidia apps for this sku
$(call inherit-product-if-exists, vendor/nvidia/$(_product_device)/skus/$(_product_name).mk)

ifeq ($(NV_ANDROID_FRAMEWORK_ENHANCEMENTS),TRUE)
PRODUCT_PACKAGE_OVERLAYS += vendor/nvidia/jetson/overlays/$(PLATFORM_VERSION_LETTER_CODE)
endif

## Calibration notifier
PRODUCT_PACKAGES += CalibNotifier
PRODUCT_COPY_FILES += \
    device/nvidia/platform/t210/calibration/calib_cfg.xml:system/etc/calib_cfg.xml

# FW check
LOCAL_FW_CHECK_TOOL_PATH=device/nvidia/common/fwcheck
LOCAL_FW_XML_PATH=vendor/nvidia/t210/skus
PRODUCT_COPY_FILES += $(call add-to-product-copy-files-if-exists, $(LOCAL_FW_XML_PATH)/fw_version.xml:$(TARGET_COPY_OUT_VENDOR)/etc/fw_version.xml) \
    $(call add-to-product-copy-files-if-exists, $(LOCAL_FW_CHECK_TOOL_PATH)/fw_check.py:fw_check.py)

# This flag is required in order to differentiate between platforms that use
# Keymaster1.0 vs the legacy keymaster 0.2 service.
USES_KEYMASTER_1 := true

ifeq ($(filter foster_e% darcy% mdarcy% sif%, $(TARGET_PRODUCT)),)
# This flag indicates that this platform uses a TLK based Gatekeeper.
USES_GATEKEEPER := true
endif

#This flag indicates vrr/rsa support
USES_GS_RSA_KEYS := false

## Clean local variables
_product_name :=
_product_device :=

