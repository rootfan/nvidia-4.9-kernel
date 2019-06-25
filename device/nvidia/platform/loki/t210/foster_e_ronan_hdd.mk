# NVIDIA Tegra7 "foster-e-ronan-hdd" development system
#
# Copyright (c) 2016-2018, NVIDIA Corporation.  All rights reserved.

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
PRODUCT_NAME := foster_e_ronan_hdd
PRODUCT_DEVICE := t210
PRODUCT_MODEL := foster_e_hdd
PRODUCT_MANUFACTURER := NVIDIA
PRODUCT_BRAND := nvidia

PRODUCT_PROPERTY_OVERRIDES += \
	ro.sf.lcd_density=320

PRODUCT_PACKAGES += \
	toolC \
	smartctl

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
$(call inherit-product-if-exists, vendor/nvidia/loki/skus/foster_e_hdd.mk)

## nvidia apps for this sku
$(call inherit-product-if-exists, vendor/nvidia/$(_product_device)/skus/$(_product_name).mk)
$(call inherit-product-if-exists, vendor/nvidia/loki/skus/tegrazone_next.mk)

## 3rd-party apps for this sku
$(call inherit-product-if-exists, 3rdparty/applications/prebuilt/common/$(_product_name).mk)

## Place here sku-specific and mp-only code.

## Clean local variables
_product_name :=
_product_device :=

