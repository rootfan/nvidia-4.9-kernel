# NVIDIA extended Vehicle HAL interface and service
#
# Copyright (c) 2017-2018 NVIDIA Corporation.  All rights reserved.

# Enable HDMI CEC service
PRODUCT_PACKAGES += \
    android.hardware.tv.cec@1.0-impl \
    android.hardware.tv.cec@1.0-service

PRODUCT_MANIFEST += device/nvidia/common/hal/cechal.xml
