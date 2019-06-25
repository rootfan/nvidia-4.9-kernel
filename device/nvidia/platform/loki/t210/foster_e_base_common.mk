# NVIDIA Tegra7 "foster-e" development system
#
# Copyright (c) 2014-2016, NVIDIA Corporation.  All rights reserved.

## This is the file that is common for mp and diag images, for a single sku.

## Common for all foster_e skus
$(call inherit-product, $(LOCAL_PATH)/foster_e_common.mk)

PRODUCT_PROPERTY_OVERRIDES += ro.radio.noril=true

FOSTER_PREBUILT_BOOTLOADER_PATH := vendor/nvidia/tegra/bootloader/prebuilt/t210/signed/Foster/prod

ifneq ($(wildcard $(FOSTER_PREBUILT_BOOTLOADER_PATH)*),)
PRODUCT_COPY_FILES += \
    $(FOSTER_PREBUILT_BOOTLOADER_PATH)/../../Foster/prod/foster_e/cboot.bin.signed:cboot.bin.signed.foster \
    $(FOSTER_PREBUILT_BOOTLOADER_PATH)/../../Foster/prod/foster_e/nvtboot.bin.signed:nvtboot.bin.signed.foster \
    $(FOSTER_PREBUILT_BOOTLOADER_PATH)/../../Foster/prod/foster_e/nvtboot_cpu.bin.signed:nvtboot_cpu.bin.signed.foster \
    $(FOSTER_PREBUILT_BOOTLOADER_PATH)/../../Foster/prod/foster_e/tos.img.signed:tos.img.signed.foster \
    $(FOSTER_PREBUILT_BOOTLOADER_PATH)/../../Foster/prod/foster_e/warmboot.bin.signed:warmboot.bin.signed.foster \
    $(FOSTER_PREBUILT_BOOTLOADER_PATH)/foster_e/flash_t210_android_sdmmc_fb.xml:flash_t210_android_sdmmc_fb.xml.signed \
    $(FOSTER_PREBUILT_BOOTLOADER_PATH)/foster_e/bct_p2530_e01.bct:bct_p2530_e01.bct \
    $(FOSTER_PREBUILT_BOOTLOADER_PATH)/foster_e_hdd/flash_t210_android_sata_fb.xml:flash_t210_android_sata_fb.xml.signed \
    $(FOSTER_PREBUILT_BOOTLOADER_PATH)/foster_e_hdd/bct_p2530_sata_e01.bct:bct_p2530_sata_e01.bct
endif

## factory script
ifeq ($(wildcard vendor/nvidia/tegra/apps/diagsuite),vendor/nvidia/tegra/apps/diagsuite)
PRODUCT_COPY_FILES += \
    vendor/nvidia/tegra/apps/diagsuite/bin/release/flags/flag_for_foster_e.txt:flag_for_foster_e.txt
endif

$(call inherit-product-if-exists, vendor/nvidia/loki/skus/tegrazone_next.mk)

$(call inherit-product, $(LOCAL_PATH)/../foster_common.mk)

# Wi-Fi country code system properties
#Check NCT magic bit to set SKU default country code
PRODUCT_PROPERTY_OVERRIDES += \
    ro.factory.wifi.nct=true

