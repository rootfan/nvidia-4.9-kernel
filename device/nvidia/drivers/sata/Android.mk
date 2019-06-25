# Copyright (c) 2015, NVIDIA CORPORATION.  All rights reserved.
#
# NVIDIA CORPORATION and its licensors retain all intellectual property
# and proprietary rights in and to this software, related documentation
# and any modifications thereto.  Any use, reproduction, disclosure or
# distribution of this software and related documentation without an express
# license agreement from NVIDIA CORPORATION is strictly prohibited.
#

LOCAL_PATH := $(call my-dir)

include $(NVIDIA_DEFAULTS)

LOCAL_SRC_FILES := tegra_sata_hal.cpp
LOCAL_MODULE := libtegra_sata_hal
LOCAL_CFLAGS := -DLOG_TAG=\"SATA\"
LOCAL_SHARED_LIBRARIES := liblog libcutils
include $(NVIDIA_SHARED_LIBRARY)

