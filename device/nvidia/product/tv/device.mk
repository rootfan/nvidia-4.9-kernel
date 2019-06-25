# Copyright (c) 2014, NVIDIA CORPORATION.  All rights reserved.

# Common stuff for tv products

PRODUCT_LOCALES := en_US

# Include drawables for various densities.
PRODUCT_AAPT_CONFIG := normal large xlarge tvdpi hdpi xhdpi xxhdpi
PRODUCT_AAPT_PREF_CONFIG := xhdpi

PRODUCT_PROPERTY_OVERRIDES += \
ro.com.google.clientidbase=android-nvidia

# we have enough storage space to hold precise GC data
PRODUCT_TAGS += dalvik.gc.type-precise

PRODUCT_CHARACTERISTICS := tv

# Set default USB interface
PRODUCT_DEFAULT_PROPERTY_OVERRIDES += \
    persist.sys.usb.config=mtp

DEVICE_PACKAGE_OVERLAYS := device/nvidia/common/overlay-common/$(PLATFORM_VERSION_LETTER_CODE)

$(call inherit-product-if-exists, device/google/atv/products/atv_base.mk)

# To enable access to /dev/dvb for untrusted 3rd party apps
ifneq ($(PLATFORM_IS_AFTER_O_MR1),1)
BOARD_SEPOLICY_DIRS += device/nvidia/product/tv/sepolicy
else
BOARD_SEPOLICY_DIRS += device/nvidia/common/sepolicy/product/tv
endif
ifeq ($(PLATFORM_IS_AFTER_N),1)
    ifneq ($(wildcard 3rdparty/google/gtvs-apps/tv),3rdparty/google/gtvs-apps/tv)
        $(call inherit-product, $(SRC_TARGET_DIR)/product/generic_no_telephony.mk)
    endif
else
    ifneq ($(wildcard 3rdparty/google/gms-apps/tv),3rdparty/google/gms-apps/tv)
        $(call inherit-product, $(SRC_TARGET_DIR)/product/generic_no_telephony.mk)
    endif
endif
