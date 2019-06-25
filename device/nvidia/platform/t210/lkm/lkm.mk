#
# Copyright (c) 2017, NVIDIA Corporation.  All Rights Reserved.
#
# NVIDIA Corporation and its licensors retain all intellectual property
# and proprietary rights in and to this software, related documentation
# and any modifications thereto.  Any use, reproduction, disclosure or
# distribution of this software and related documentation without an express
# license agreement from NVIDIA Corporation is strictly prohibited.
#


ifeq ($(NV_ANDROID_FRAMEWORK_ENHANCEMENTS), TRUE)
PRODUCT_COPY_FILES += \
    device/nvidia/platform/t210/lkm/lkm_loader.sh:vendor/bin/lkm_loader.sh
else
PRODUCT_COPY_FILES += \
    device/nvidia/platform/t210/lkm/lkm_loader.sh.old:vendor/bin/lkm_loader.sh
endif

PRODUCT_COPY_FILES += \
    device/nvidia/platform/t210/lkm/init.lkm.rc:root/init.lkm.rc

