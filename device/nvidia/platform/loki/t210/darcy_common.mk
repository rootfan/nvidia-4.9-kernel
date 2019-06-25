# NVIDIA Tegra7 "foster-e" development system
#
# Copyright (c) 2016-2018, NVIDIA Corporation.  All rights reserved.

## This is the file that is common for mp and diag images, for a single sku.

## Common for all foster_e skus
$(call inherit-product, $(LOCAL_PATH)/foster_e_common.mk)

## Verified boot
$(call inherit-product, $(LOCAL_PATH)/darcy_verity.mk)

PRODUCT_PACKAGES += \
    slideshow \
    verity_warning_images

PRODUCT_COPY_FILES += \
    frameworks/native/data/etc/android.software.verified_boot.xml:system/etc/permissions/android.software.verified_boot.xml

PRODUCT_PROPERTY_OVERRIDES += \
    ro.restart.veritymode=logging

PRODUCT_PROPERTY_OVERRIDES += ro.radio.noril=true

PREBUILT_BOOTLOADER_PATH := vendor/nvidia/tegra/bootloader/prebuilt/t210/signed

#Foster prebuilt binaries are added since foster share darcy dev build for sanity.
ifneq ($(wildcard $(PREBUILT_BOOTLOADER_PATH)*),)
PRODUCT_COPY_FILES += \
    $(PREBUILT_BOOTLOADER_PATH)/MDarcy/prod/mdarcy/cboot.bin.signed:cboot.bin.signed.mdarcy \
    $(PREBUILT_BOOTLOADER_PATH)/MDarcy/prod/mdarcy/nvtboot.bin.signed:nvtboot.bin.signed.mdarcy \
    $(PREBUILT_BOOTLOADER_PATH)/MDarcy/prod/mdarcy/nvtboot_cpu.bin.signed:nvtboot_cpu.bin.signed.mdarcy \
    $(PREBUILT_BOOTLOADER_PATH)/MDarcy/prod/mdarcy/tos.img.signed:tos.img.signed.mdarcy \
    $(PREBUILT_BOOTLOADER_PATH)/MDarcy/prod/mdarcy/warmboot.bin.signed:warmboot.bin.signed.mdarcy \
    $(PREBUILT_BOOTLOADER_PATH)/MDarcy/prod/mdarcy/flash_t210_darcy_android_sdmmc.xml:flash_t210_darcy_android_sdmmc.xml.signed \
    $(PREBUILT_BOOTLOADER_PATH)/MDarcy/prod/mdarcy/bct_p2894.bct:bct_p2894.bct \
    $(PREBUILT_BOOTLOADER_PATH)/Foster/prod/foster_e/cboot.bin.signed:cboot.bin.signed.foster \
    $(PREBUILT_BOOTLOADER_PATH)/Foster/prod/foster_e/nvtboot.bin.signed:nvtboot.bin.signed.foster \
    $(PREBUILT_BOOTLOADER_PATH)/Foster/prod/foster_e/nvtboot_cpu.bin.signed:nvtboot_cpu.bin.signed.foster \
    $(PREBUILT_BOOTLOADER_PATH)/Foster/prod/foster_e/tos.img.signed:tos.img.signed.foster \
    $(PREBUILT_BOOTLOADER_PATH)/Foster/prod/foster_e/warmboot.bin.signed:warmboot.bin.signed.foster \
    $(PREBUILT_BOOTLOADER_PATH)/Foster/prod/foster_e/flash_t210_android_sdmmc_fb.xml:flash_t210_android_sdmmc_fb.xml.signed \
    $(PREBUILT_BOOTLOADER_PATH)/Foster/prod/foster_e/bct_p2530_e01.bct:bct_p2530_e01.bct \
    $(PREBUILT_BOOTLOADER_PATH)/Foster/prod/foster_e_hdd/flash_t210_android_sata_fb.xml:flash_t210_android_sata_fb.xml.signed \
    $(PREBUILT_BOOTLOADER_PATH)/Foster/prod/foster_e_hdd/bct_p2530_sata_e01.bct:bct_p2530_sata_e01.bct
endif

PRODUCT_COPY_FILES += \
	device/nvidia/common/init.nv_dev_board.usb.rc:root/init.nv_dev_board.usb.rc \
	device/nvidia/common/init.recovery.android.usb.rc:root/init.recovery.usb.rc

## verity partitions
PRODUCT_SYSTEM_VERITY_PARTITION := /dev/block/platform/sdhci-tegra.3/by-name/APP
PRODUCT_VENDOR_VERITY_PARTITION := /dev/block/platform/sdhci-tegra.3/by-name/vendor

## factory script
ifeq ($(wildcard vendor/nvidia/tegra/apps/diagsuite),vendor/nvidia/tegra/apps/diagsuite)
PRODUCT_COPY_FILES += \
    vendor/nvidia/tegra/apps/diagsuite/bin/release/flags/flag_for_foster_e.txt:flag_for_foster_e.txt
endif

## Product bpmp firmware
PRODUCT_PACKAGES += \
    bpmp_p3425_sif_t210b01

$(call inherit-product, $(LOCAL_PATH)/../foster_common.mk)

