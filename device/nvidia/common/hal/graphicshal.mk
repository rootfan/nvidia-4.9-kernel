# Copyright (c) 2017-2018 NVIDIA Corporation.  All rights reserved.

PRODUCT_PACKAGES += \
    android.hardware.graphics.allocator@2.0-impl \
    android.hardware.graphics.allocator@2.0-service \
    android.hardware.graphics.mapper@2.0-impl \
    vendor.nvidia.hardware.graphics.composer@1.0-impl \
    vendor.nvidia.hardware.graphics.display@1.0-impl \
    vendor.nvidia.hardware.graphics.composer@1.0-service \
    hwcservice_client

PRODUCT_MANIFEST += device/nvidia/common/hal/graphicshal.xml
