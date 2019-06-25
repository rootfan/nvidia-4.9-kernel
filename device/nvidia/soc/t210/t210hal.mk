# Copyright (c) 2018 NVIDIA Corporation.  All rights reserved.

# List vendor HALs in alphabetical order

# Audio HAL
include device/nvidia/common/hal/audiohal.mk

# BootControl HAL
include device/nvidia/common/hal/boothal.mk

# Camera HAL
include device/nvidia/common/hal/camerahal.mk

# CEC HAL
include device/nvidia/common/hal/cechal.mk

# dumpstate HAL
include device/nvidia/common/hal/dumpstatehal.mk

# GenSysfs HAL
include device/nvidia/common/hal/gensysfshal.mk

ifeq ($(NV_ANDROID_FRAMEWORK_ENHANCEMENTS), TRUE)
ifeq ($(filter foster_e% darcy% mdarcy% sif%, $(TARGET_PRODUCT)),)
# Gatekeper HAL
include device/nvidia/common/hal/gatekeeperhal.mk
endif
endif

# Graphic HAL
include device/nvidia/common/hal/graphicshal.mk

# Keymaster HAL
include device/nvidia/common/hal/keymasterhal.mk

# Memtrack
include device/nvidia/common/hal/memtrackhal.mk

# OMX HAL
include device/nvidia/common/hal/omxhal.mk

# PHS HAL
include device/nvidia/common/hal/phshal.mk

# Power HAL
include device/nvidia/common/hal/powerhal.mk

# USB HAL
include device/nvidia/common/hal/usbhal.mk
