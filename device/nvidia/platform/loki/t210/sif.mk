# NVIDIA Tegra 210b01 "sif" development system
#
# Copyright (c) 2018, NVIDIA Corporation.  All rights reserved.

## All essential packages
$(call inherit-product, device/nvidia/soc/t210/device-t210.mk)
$(call inherit-product, device/nvidia/product/tv/device.mk)
$(call inherit-product, device/nvidia/platform/t210/device.mk)

## Install GMS if available
$(call inherit-product-if-exists, $(LOCAL_PATH)/sif_gms.mk)

PRODUCT_PROPERTY_OVERRIDES += \
        ro.com.google.clientidbase=android-nvidia

# set default kernel to 4.9
KERNEL_PATH=$(CURDIR)/kernel/kernel-4.9

## Thse are default settings, it gets changed as per sku manifest properties
PRODUCT_NAME := sif
PRODUCT_DEVICE := t210
PRODUCT_MODEL := sif
PRODUCT_MANUFACTURER := NVIDIA
PRODUCT_BRAND := nvidia

PRODUCT_PROPERTY_OVERRIDES += \
	ro.sf.lcd_density=320

PRODUCT_PROPERTY_OVERRIDES += \
    ro.product.first_api_level=23

ifeq ($(TARGET_BUILD_VARIANT),user)
PRODUCT_PROPERTY_OVERRIDES += persist.convertible.usb.mode=host
else
PRODUCT_PROPERTY_OVERRIDES += persist.convertible.usb.mode=device
endif

PRODUCT_PACKAGES += \
    slideshow \
    verity_warning_images

## Values of PRODUCT_NAME and PRODUCT_DEVICE are mangeled before it can be
## used because of call to inherits, store their values to use later in this
## file below
_product_name := $(strip $(PRODUCT_NAME))
_product_device := $(strip $(PRODUCT_DEVICE))

# This flag is required in order to differentiate between platforms that use
# Keymaster1.0 vs the legacy keymaster 0.3 service.
USES_KEYMASTER_1 := true

#SHIELDBeta
PRODUCT_PACKAGES += \
    SHIELDBeta

#SHIELD user registration
PRODUCT_PACKAGES += \
    NvRegistration

PRODUCT_PACKAGES += \
    VUDUAndroidTV4K

## common for mp and diag images, for a single sku.
$(call inherit-product, $(LOCAL_PATH)/darcy_common.mk)

## Factory scripts, common for mp images, among multiple skus.
$(call inherit-product-if-exists, vendor/nvidia/diag/common/mp_common.mk)

## common apps for all skus
$(call inherit-product-if-exists, vendor/nvidia/loki/skus/sif.mk)
$(call inherit-product-if-exists, vendor/nvidia/loki/skus/foster_common.mk)

## nvidia apps for this sku
$(call inherit-product-if-exists, vendor/nvidia/$(_product_device)/skus/$(_product_name).mk)

## 3rd-party apps for this sku
$(call inherit-product-if-exists, 3rdparty/applications/prebuilt/common/$(_product_name).mk)
$(call inherit-product-if-exists, vendor/nvidia/loki/skus/tegrazone_next.mk)

## eks2 data blob
PRODUCT_COPY_FILES += \
    $(call add-to-product-copy-files-if-exists, vendor/nvidia/tegra/ote/nveks2/data/eks2_darcy.dat:vendor/app/eks2/eks2.dat) \
    $(call add-to-product-copy-files-if-exists, vendor/nvidia/tegra/ote/nveks2/data/eks2_mdarcy.dat:vendor/app/eks2/eks2_mdarcy.dat)

MDARCY_PREBUILT_BOOTLOADER_PATH := vendor/nvidia/tegra/bootloader/prebuilt/t210/signed/MDarcy/prod

ifneq ($(wildcard $(MDARCY_PREBUILT_BOOTLOADER_PATH)*),)
PRODUCT_COPY_FILES += \
    $(MDARCY_PREBUILT_BOOTLOADER_PATH)/mdarcy/bct_p2894_t210b01.bct:bct_p2894_t210b01.bct \
    $(MDARCY_PREBUILT_BOOTLOADER_PATH)/mdarcy/bct_p2894_t210b01_rcm.bct:bct_p2894_t210b01_rcm.bct \
    $(MDARCY_PREBUILT_BOOTLOADER_PATH)/mdarcy/cboot_t210b01.bin.signed:cboot_t210b01.bin.signed.mdarcy \
    $(MDARCY_PREBUILT_BOOTLOADER_PATH)/mdarcy/flash_t210b01_darcy_android_sdmmc.xml:flash_t210b01_darcy_android_sdmmc.xml.signed \
    $(MDARCY_PREBUILT_BOOTLOADER_PATH)/mdarcy/nvtboot_t210b01_encrypt_header.bin.signed:nvtboot_t210b01_encrypt_header.bin.signed.mdarcy \
    $(MDARCY_PREBUILT_BOOTLOADER_PATH)/mdarcy/nvtboot_cpu_t210b01.bin.signed:nvtboot_cpu_t210b01.bin.signed.mdarcy \
    $(MDARCY_PREBUILT_BOOTLOADER_PATH)/mdarcy/tlk_tos_t210b01.img.signed:tlk_tos_t210b01.img.signed.mdarcy \
    $(MDARCY_PREBUILT_BOOTLOADER_PATH)/mdarcy/warmboot_encrypt_t210b01.bin.signed:warmboot_encrypt_t210b01.bin.signed.mdarcy
endif

## mdarcy UDA diag entry
$(call inherit-product-if-exists, vendor/nvidia/tegra/apps/factory/uda_diag/device_nvidia/platform/loki/t210/sif.mk)

## Clean local variables
_product_name :=
_product_device :=

