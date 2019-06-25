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
    vendor/nvidia/tegra/apps/diagsuite/bin/release/flags/flag_for_loki_e_wifi.txt:flag_for_loki_e_wifi.txt
endif

$(call inherit-product, $(LOCAL_PATH)/../loki_common.mk)

