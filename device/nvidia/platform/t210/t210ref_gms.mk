# Copyright (c) 2014-2015 NVIDIA Corporation.  All rights reserved.

$(call inherit-product, $(LOCAL_PATH)/t210ref.mk)
TARGET_GMS_TABLET_ARCH := arm64
$(call inherit-product, 3rdparty/google/gms-apps/tablet/products/gms.mk)

PRODUCT_PROPERTY_OVERRIDES += \
ro.com.google.clientidbase=android-nvidia

PRODUCT_NAME := t210ref_gms
PRODUCT_BRAND := nvidia
