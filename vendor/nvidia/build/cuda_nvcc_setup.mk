###############################################################################
#
# Copyright (c) 2017, NVIDIA CORPORATION.  All rights reserved.
#
# NVIDIA CUDA Compiler Setup
#
# Use global: TARGET_ARCH
#             TARGET_2ND_ARCH
#             CUDA_TOOLKIT_PATH
#
# Input:  my_prefix
#         LOCAL_NVIDIA_NVCC_CFLAGS
#         LOCAL_NVIDIA_NVCC_LDFLAGS
#         LOCAL_*
#
# Output: my_nvcc          : NVIDIA Cuda Compiler binary location
#         my_nvcc_cflags   : Parameters for .cu to .o compilation
#         my_nvcc_ldflags  : Parameters for .o to library compilation
#
# Modify: LOCAL_EXPORT_C_INCLUDE_DIRS
#
###############################################################################

my_nvcc_cflags := $(LOCAL_NVIDIA_NVCC_CFLAGS)
my_nvcc_ldflags := $(LOCAL_NVIDIA_NVCC_LDFLAGS)

ifeq ($(strip $($(my_prefix)$(LOCAL_2ND_ARCH_VAR_PREFIX)ARCH)), arm)
 my_nvcc_cflags  += -m32 -DARCH_ARM
 my_nvcc_ldflags += -m32
 my_cuda_eabi    := armv7-linux-androideabi
else # implies 64 bits
 my_nvcc_cflags  += -m64 -DARCH_AARCH64
 my_nvcc_ldflags += -m64
 my_cuda_eabi    := aarch64-linux-androideabi
endif

# Try to use module-defined CUDA toolkit path; otherwise, use default toolkit.
ifneq ($(LOCAL_NVIDIA_CUDA_TOOLKIT_PATH),)
 my_cuda_toolkit_include := $(LOCAL_NVIDIA_CUDA_TOOLKIT_PATH)/include
 my_cuda_toolkit_root := $(LOCAL_NVIDIA_CUDA_TOOLKIT_PATH)/targets/$(my_cuda_eabi)
 my_nvcc := $(LOCAL_NVIDIA_CUDA_TOOLKIT_PATH)/bin/nvcc
else
 my_cuda_toolkit_include := $(CUDA_TOOLKIT_PATH)/include
 my_cuda_toolkit_root := $(CUDA_TOOLKIT_PATH)/targets/$(my_cuda_eabi)
 my_nvcc := $(CUDA_TOOLKIT_PATH)/bin/nvcc
endif

ifeq ($(TARGET_TEGRA_VERSION), t186)
my_nvcc_cflags += -gencode arch=compute_62,code=sm_62
else ifeq ($(TARGET_TEGRA_VERSION), t210)
my_nvcc_cflags += -gencode arch=compute_53,code=sm_53
else
my_nvcc_cflags += -gencode arch=compute_32,code=sm_32
endif

my_nvcc_cflags += -I$(my_cuda_toolkit_include)

my_nvcc_ldflags += -lib

ifeq ($(TARGET_BUILD_TYPE),debug)
# Generate debug information for host code.
my_nvcc_cflags += -g
else
my_nvcc_cflags += -O3
endif

#
# Warning: the following flags are inherited from ancient setup,
#          they might not fit to all cuda libraries any more and
#          should be reviewed.
#
my_nvcc_cflags += --use_fast_math
my_nvcc_cflags += -Xptxas '-dlcm=ca'
my_nvcc_cflags += -DDEBUG_MODE

LOCAL_EXPORT_C_INCLUDE_DIRS := $(LOCAL_EXPORT_C_INCLUDE_DIRS) $(my_cuda_toolkit_root)/include
