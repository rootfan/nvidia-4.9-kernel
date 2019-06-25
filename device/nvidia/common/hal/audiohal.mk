# NVIDIA Tegra development system
# Audio HAL interface and service
#
# Copyright (c) 2018 NVIDIA Corporation.  All rights reserved.

PRODUCT_PACKAGES += \
    android.hardware.audio@2.0-service \
    android.hardware.audio.effect@2.0-impl \
    android.hardware.audio@2.0-impl \
    android.hardware.soundtrigger@2.0-impl

PRODUCT_MANIFEST += device/nvidia/common/hal/audiohal.xml
