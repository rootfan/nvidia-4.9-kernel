#
# Copyright (c) 2017, NVIDIA CORPORATION.  All rights reserved.
#
# Nvidia CUDA target shared library
#

LOCAL_MODULE_CLASS          := SHARED_LIBRARIES
LOCAL_MODULE_SUFFIX         := .so

LOCAL_CFLAGS                := $(LOCAL_CFLAGS) -fPIC
LOCAL_NVIDIA_NVCC_LDFLAGS   := $(LOCAL_NVIDIA_NVCC_LDFLAGS) -shared

LOCAL_STATIC_LIBRARIES      := $(LOCAL_STATIC_LIBRARIES) libcudart_static
LOCAL_SHARED_LIBRARIES      := $(LOCAL_SHARED_LIBRARIES) libdl

my_cuda_library_internal    := $(NVIDIA_BUILD_ROOT)/cuda_shared_library_internal.mk

include $(NVIDIA_BUILD_ROOT)/cuda_library_common.mk
