#
# Copyright (c) 2017, NVIDIA CORPORATION.  All rights reserved.
#
# Nvidia CUDA target static library
#

LOCAL_UNINSTALLABLE_MODULE  := true
LOCAL_MODULE_CLASS          := STATIC_LIBRARIES
LOCAL_MODULE_SUFFIX         := .a

my_cuda_library_internal    := $(NVIDIA_BUILD_ROOT)/cuda_static_library_internal.mk

include $(NVIDIA_BUILD_ROOT)/cuda_library_common.mk
