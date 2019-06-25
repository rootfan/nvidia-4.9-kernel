# NVIDIA Tegra7 "foster-e-hdd" development system
#
# Copyright (c) 2014-2018, NVIDIA Corporation.  All rights reserved.

## All essential packages
$(call inherit-product, device/nvidia/soc/t210/device-t210.mk)
$(call inherit-product, device/nvidia/product/tv/device.mk)
$(call inherit-product, device/nvidia/platform/t210/device.mk)

## Install GMS if available
ifeq ($(PLATFORM_IS_AFTER_N),1)
    $(call inherit-product-if-exists, 3rdparty/google/gtvs-apps/tv/64/products/gms.mk)
else
    $(call inherit-product-if-exists, 3rdparty/google/gms-apps/tv/64/products/gms.mk)
endif
PRODUCT_PROPERTY_OVERRIDES += \
        ro.com.google.clientidbase=android-nvidia

# set default kernel to K4.9
KERNEL_PATH=$(CURDIR)/kernel/kernel-4.9

## Thse are default settings, it gets changed as per sku manifest properties
PRODUCT_NAME := foster_e_hdd
PRODUCT_DEVICE := t210
PRODUCT_MODEL := foster_e_hdd
PRODUCT_MANUFACTURER := NVIDIA
PRODUCT_BRAND := nvidia

PRODUCT_PROPERTY_OVERRIDES += \
	ro.sf.lcd_density=320

PRODUCT_PACKAGES += \
	toolC \
	smartctl

PRODUCT_PACKAGES += \
    VUDUAndroidTV4K

#SHIELD user registration
PRODUCT_PACKAGES += \
    NvRegistration

## Values of PRODUCT_NAME and PRODUCT_DEVICE are mangeled before it can be
## used because of call to inherits, store their values to use later in this
## file below
_product_name := $(strip $(PRODUCT_NAME))
_product_device := $(strip $(PRODUCT_DEVICE))

## common for mp and diag images, for a single sku.
$(call inherit-product, $(LOCAL_PATH)/foster_e_hdd_common.mk)

## Factory scripts, common for mp images, among multiple skus.
$(call inherit-product-if-exists, vendor/nvidia/diag/common/mp_common.mk)

## common apps for all skus
$(call inherit-product-if-exists, vendor/nvidia/loki/skus/$(_product_name).mk)

## nvidia apps for this sku
$(call inherit-product-if-exists, vendor/nvidia/$(_product_device)/skus/$(_product_name).mk)

## 3rd-party apps for this sku
$(call inherit-product-if-exists, 3rdparty/applications/prebuilt/common/$(_product_name).mk)
$(call inherit-product-if-exists, vendor/nvidia/loki/skus/tegrazone_next.mk)

## eks2 data blob
PRODUCT_COPY_FILES += \
    $(call add-to-product-copy-files-if-exists, vendor/nvidia/tegra/ote/nveks2/data/eks2_foster.dat:vendor/app/eks2/eks2.dat)

# SmartThings for non-licensed builds
ifeq ($(NV_ANDROID_FRAMEWORK_ENHANCEMENTS),TRUE)
PRODUCT_PACKAGES += \
    hubcore
PRODUCT_COPY_FILES += \
    vendor/nvidia/tegra/3rdparty/smartthings/com.smartthings.hubcore.xml:system/etc/permissions/com.smartthings.hubcore.xml \
    vendor/nvidia/tegra/3rdparty/smartthings/stConfig:vendor/etc/smartthings/stConfig \
    vendor/nvidia/tegra/3rdparty/smartthings/stConfig_dev:vendor/etc/smartthings/stConfig_dev \
    vendor/nvidia/tegra/3rdparty/smartthings/stTLSCA_dc:vendor/etc/smartthings/stTLSCA_dc \
    vendor/nvidia/tegra/3rdparty/smartthings/sonos-combined-device-root.pem:vendor/etc/smartthings/caCerts/sonos-combined-device-root.pem \
    vendor/nvidia/tegra/3rdparty/smartthings/stZigbee:vendor/firmware/stZigbee
endif

## Clean local variables
_product_name :=
_product_device :=

