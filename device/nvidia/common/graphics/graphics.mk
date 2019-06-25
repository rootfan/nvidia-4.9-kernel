# Copyright (c) 2016 NVIDIA Corporation.  All rights reserved.
#
# Common options for graphics

# OPENGL AEP permission file
PRODUCT_COPY_FILES += \
    frameworks/native/data/etc/android.hardware.opengles.aep.xml:system/etc/permissions/android.hardware.opengles.aep.xml

ifeq ($(PLATFORM_IS_AFTER_M),1)
# Vulkan Support: level and version.  This is feature level and doesn't
# necessarily have to exactly match the apiVersion reported by the driver.
PRODUCT_COPY_FILES += \
    frameworks/native/data/etc/android.hardware.vulkan.level-1.xml:system/etc/permissions/android.hardware.vulkan.level.xml \
    frameworks/native/data/etc/android.hardware.vulkan.version-1_0_3.xml:system/etc/permissions/android.hardware.vulkan.version.xml
endif
ifeq ($(PLATFORM_IS_AFTER_N),1)
PRODUCT_COPY_FILES += \
    frameworks/native/data/etc/android.hardware.vulkan.compute-0.xml:system/etc/permissions/android.hardware.vulkan.compute.xml
endif
