# Copyright (c) 2014, NVIDIA CORPORATION.  All rights reserved.

# Common stuff for tablet products

PRODUCT_LOCALES += en_US

# we have enough storage space to hold precise GC data
PRODUCT_TAGS += dalvik.gc.type-precise

PRODUCT_CHARACTERISTICS := tablet

# Set default USB interface
PRODUCT_DEFAULT_PROPERTY_OVERRIDES += \
    persist.sys.usb.config=mtp

DEVICE_PACKAGE_OVERLAYS := device/nvidia/common/overlay-common/$(PLATFORM_VERSION_LETTER_CODE)
