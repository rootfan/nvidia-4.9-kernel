# Copyright (c) 2013-2017, NVIDIA CORPORATION.  All rights reserved.
#
# NVIDIA CORPORATION and its licensors retain all intellectual property
# and proprietary rights in and to this software, related documentation
# and any modifications thereto.  Any use, reproduction, disclosure or
# distribution of this software and related documentation without an express
# license agreement from NVIDIA CORPORATION is strictly prohibited.

ifeq ($(NVIDIA_POST_INCLUDED),false)
$(error $(PREV_LOCAL_PATH) NVIDIA_DEFAULTS called without defining a module)
endif

# Grab name of the makefile to depend on it
ifneq ($(PREV_LOCAL_PATH),$(LOCAL_PATH))
NVIDIA_MAKEFILE := $(lastword $(filter-out $(lastword $(MAKEFILE_LIST)),$(MAKEFILE_LIST)))
PREV_LOCAL_PATH := $(LOCAL_PATH)
endif

# Include Bullseye libcov component definition
# Performed here to ensure that the library is included as part of all "mm"
# builds.
include $(NVIDIA_BULLSEYE_LIBCOV)

# Clear all local variables
include $(NVIDIA_CLEAR_VARS_INTERNAL)

# Store values of variables that we may need to override and restore in post.mk
NVIDIA_SAVED_CC_WRAPPER := $(CC_WRAPPER)
NVIDIA_SAVED_CXX_WRAPPER := $(CXX_WRAPPER)

# Build variables common to all nvidia modules

LOCAL_C_INCLUDES += $(TEGRA_TOP)/display/nvdc/include
LOCAL_C_INCLUDES += $(TEGRA_TOP)/core/include
LOCAL_C_INCLUDES += $(TEGRA_TOP)/hwinc
LOCAL_C_INCLUDES += $(TEGRA_TOP)/hwinc/$(TARGET_TEGRA_FAMILY)
LOCAL_C_INCLUDES += $(TEGRA_TOP)/hwinc-$(TARGET_TEGRA_FAMILY)
LOCAL_C_INCLUDES += $(TEGRA_TOP)/camera/core/include
LOCAL_C_INCLUDES += $(TEGRA_TOP)/multimedia/codecs/include
LOCAL_C_INCLUDES += $(TEGRA_TOP)/multimedia/audio/include
LOCAL_C_INCLUDES += $(TEGRA_TOP)/multimedia/tvmr/include
LOCAL_C_INCLUDES += $(TEGRA_TOP)/multimedia-partner/utils/include
LOCAL_C_INCLUDES += $(TEGRA_TOP)/multimedia-partner/nvmm/include
LOCAL_C_INCLUDES += $(TEGRA_TOP)/multimedia-partner/openmax/include
LOCAL_C_INCLUDES += $(TEGRA_TOP)/camera-partner/imager/include
LOCAL_C_INCLUDES += $(TEGRA_TOP)/camera/core_v3/hwinc/$(TARGET_TEGRA_FAMILY)
LOCAL_C_INCLUDES += $(TEGRA_TOP)/camera/core_v3/hwinc
LOCAL_C_INCLUDES += $(TEGRA_TOP)/camera/core/camera
LOCAL_C_INCLUDES += $(TEGRA_TOP)/core-private/include

ifneq (,$(findstring core-private,$(LOCAL_PATH)))
LOCAL_C_INCLUDES += $(TEGRA_TOP)/core-private/include
LOCAL_C_INCLUDES += $(TEGRA_TOP)/hwinc-private
LOCAL_C_INCLUDES += $(TEGRA_TOP)/hwinc-private/$(TARGET_TEGRA_FAMILY)
endif

ifneq (,$(findstring tests,$(LOCAL_PATH)))
LOCAL_C_INCLUDES += $(TEGRA_TOP)/core-private/include
LOCAL_C_INCLUDES += $(TEGRA_TOP)/core-t19x/include
endif

-include $(NVIDIA_UBM_DEFAULTS)

TEGRA_CFLAGS :=

# Following line has been added to prevent redefinition of NV_DEBUG
LOCAL_CFLAGS += -UNV_DEBUG
# NOTE: this conditional needs to be kept in sync with the one in base.mk!
ifeq ($(TARGET_BUILD_TYPE),debug)
LOCAL_CFLAGS += -DNV_DEBUG=1
# TODO: fix source that relies on these
LOCAL_CFLAGS += -DDEBUG
LOCAL_CFLAGS += -D_DEBUG
# disable all optimizations and enable gdb debugging extensions
LOCAL_CFLAGS += -O0 -ggdb
else
LOCAL_CFLAGS += -DNV_DEBUG=0
endif

LOCAL_CFLAGS += -DNV_IS_AVP=0
LOCAL_CFLAGS += -DNV_BUILD_STUBS=1
TEGRA_CFLAGS += -DCONFIG_PLLP_BASE_AS_408MHZ=1

# Pass value of NV_BUILD_CONFIGURATION_EXPOSING flags in the compiler flags
LOCAL_CFLAGS += -DNV_BUILD_CONFIGURATION_EXPOSING_T18X=$(NV_BUILD_CONFIGURATION_EXPOSING_T18X)
LOCAL_CFLAGS += -DNV_BUILD_CONFIGURATION_EXPOSING_T19X=$(NV_BUILD_CONFIGURATION_EXPOSING_T19X)

# Android uses sync FDs as the native synchronization primitive in the
# GPU driver code paths
NV_GPU_USE_SYNC_FD := 1

# Set this flag by default for T124 bootloader
TEGRA_CFLAGS += -DCONFIG_NONTZ_BL

ifeq ($(NV_EMBEDDED_BUILD),1)
TEGRA_CFLAGS += -DNV_EMBEDDED_BUILD
endif

ifdef PLATFORM_IS_JELLYBEAN
LOCAL_CFLAGS += -DPLATFORM_IS_JELLYBEAN=1
endif
ifdef PLATFORM_IS_JELLYBEAN_MR1
LOCAL_CFLAGS += -DPLATFORM_IS_JELLYBEAN_MR1=1
endif
ifdef PLATFORM_IS_JELLYBEAN_MR2
LOCAL_CFLAGS += -DPLATFORM_IS_JELLYBEAN_MR2=1
endif
ifdef PLATFORM_IS_KITKAT
LOCAL_CFLAGS += -DPLATFORM_IS_KITKAT=1
endif
ifdef PLATFORM_IS_AFTER_KITKAT
LOCAL_CFLAGS += -DPLATFORM_IS_AFTER_KITKAT=1
endif
ifdef PLATFORM_IS_AFTER_LOLLIPOP
LOCAL_CFLAGS += -DPLATFORM_IS_AFTER_LOLLIPOP=1
endif
ifdef PLATFORM_IS_AFTER_M
LOCAL_CFLAGS += -DPLATFORM_IS_AFTER_M=1
endif
ifdef PLATFORM_IS_AFTER_N
LOCAL_CFLAGS += -DPLATFORM_IS_AFTER_N=1
endif
ifdef PLATFORM_IS_AFTER_O_MR0
LOCAL_CFLAGS += -DPLATFORM_IS_AFTER_O_MR0=1
endif
ifdef PLATFORM_IS_AFTER_O_MR1
LOCAL_CFLAGS += -DPLATFORM_IS_AFTER_O_MR1=1
endif

ifdef PLATFORM_IS_GTV_HC
LOCAL_CFLAGS += -DPLATFORM_IS_GTV_HC=1
endif

# Non-Secure Profiling (ARM - Non-Invasive Debug Enable)
TEGRA_CFLAGS += -DNON_SECURE_PROF=0

LOCAL_CFLAGS += $(TEGRA_CFLAGS)
LOCAL_ASFLAGS += $(TEGRA_CFLAGS)

ifneq (,$(findstring _sim, $(TARGET_PRODUCT)))
LOCAL_CFLAGS += -DBUILD_FOR_COSIM
endif

LOCAL_MODULE_TAGS := optional

# Set internal template variables to defaults
NVIDIA_POST_INCLUDED := false
NVIDIA_CLEARED := true
NVIDIA_APICHECK := true
LOCAL_IS_NVIDIA_TEST :=

# FIXME: GTV's toolchain generates a lot of warnings for now
ifdef PLATFORM_IS_GTV_HC
LOCAL_NVIDIA_NO_WARNINGS_AS_ERRORS := 1
endif

include $(NVIDIA_BUILD_MODULARIZATION_BASE)
