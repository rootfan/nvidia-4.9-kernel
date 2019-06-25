# NVIDIA Tegra7 "loki-e" development system
#
# Copyright (c) 2014, NVIDIA Corporation.  All rights reserved.
#
# AndroidProducts.mk is included before BoardConfig.mk, variable essential at
# start of build and used in here should always be intialized in this file

## This is the file that is common for mp and diag images, for a single sku.

## Common for all loki_e skus
$(call inherit-product, $(LOCAL_PATH)/loki_e_common.mk)

PRODUCT_PROPERTY_OVERRIDES += ro.radio.noril=true

PRODUCT_PACKAGE_OVERLAYS += $(LOCAL_PATH)/../overlays/$(PLATFORM_VERSION_LETTER_CODE)/wifi

## factory script, is this even required anymore?
ifeq ($(wildcard vendor/nvidia/tegra/apps/diagsuite),vendor/nvidia/tegra/apps/diagsuite)
PRODUCT_COPY_FILES += \
    vendor/nvidia/tegra/apps/diagsuite/bin/release/flags/flag_for_loki_e_wifi.txt:flag_for_loki_e_tab_os.txt
endif

PRODUCT_COPY_FILES += \
     frameworks/native/data/etc/tablet_core_hardware.xml:system/etc/permissions/tablet_core_hardware.xml \
     frameworks/native/data/etc/android.hardware.touchscreen.multitouch.jazzhand.xml:system/etc/permissions/android.hardware.touchscreen.multitouch.jazzhand.xml \
     frameworks/native/data/etc/android.hardware.sensor.accelerometer.xml:system/etc/permissions/android.hardware.sensor.accelerometer.xml \
     frameworks/native/data/etc/android.hardware.sensor.gyroscope.xml:system/etc/permissions/android.hardware.sensor.gyroscope.xml \
     $(LOCAL_PATH)/handheld_core_hardware_loki_e.xml:system/etc/permissions/handheld_core_hardware.xml

$(call inherit-product, $(LOCAL_PATH)/../loki_common.mk)

