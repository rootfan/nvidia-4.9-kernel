#
# Copyright (c) 2016, Google Inc.  All rights reserved.
# Copyright (c) 2013-2017, NVIDIA CORPORATION.  All rights reserved.
#
# Nvidia CUDA target shared library
#

######################################################
#
# CUDA specific modifications to LOCAL_*
#
# Note: currently nvcc does not support clang / libc++
#
######################################################

ifeq ($(LOCAL_CXX_STL), libc++)
 $(warning #########################################################)
 $(warning # libc++ is not officially supported by CUDA compiler,  #)
 $(warning # compilation is not guarateed to work                  #)
 $(warning #########################################################)
endif

ifeq ($(LOCAL_NDK_STL_VARIANT)$(LOCAL_SDK_VERSION)$(LOCAL_CXX_STL), default)
 ifeq ($(PLATFORM_IS_AFTER_N), 1)
  LOCAL_USE_VENDOR_GNUSTL := true
 else
  LOCAL_SDK_VERSION := 21
  LOCAL_NDK_STL_VARIANT := gnustl_static
 endif
endif

ifneq ($(LOCAL_NDK_STL_VARIANT)$(LOCAL_SDK_VERSION),)
 # gnustl_static comes from ndk, and in Android O, ndk is not prebuilt, need to build at compile time
 ifeq ($(PLATFORM_IS_AFTER_N),1)
  LOCAL_ADDITIONAL_DEPENDENCIES := $(LOCAL_ADDITIONAL_DEPENDENCIES) $(SOONG_OUT_DIR)/ndk.timestamp
 endif
endif

ifeq ($(LOCAL_CLANG),)
 LOCAL_CLANG := false
endif

###########################################
#
# multi-arch definition
#
###########################################

NVIDIA_TEMPLATE_SUPPORTS_BUILD_MODULARIZATION := true

include $(NVIDIA_BASE)

my_prefix := TARGET_
include $(BUILD_SYSTEM)/multilib.mk

# libraries default to build for both architecturess
ifndef my_module_multilib
 my_module_multilib := both
endif

ifeq ($(my_module_multilib),both)
 ifneq ($(LOCAL_MODULE_PATH),)
  ifneq ($(TARGET_2ND_ARCH),)
   $(warning $(LOCAL_MODULE): LOCAL_MODULE_PATH for shared libraries is unsupported in multiarch builds, use LOCAL_MODULE_RELATIVE_PATH instead)
  endif
 endif

 ifneq ($(LOCAL_UNSTRIPPED_PATH),)
  ifneq ($(TARGET_2ND_ARCH),)
   $(warning $(LOCAL_MODULE): LOCAL_UNSTRIPPED_PATH for shared libraries is unsupported in multiarch builds)
  endif
 endif
endif # my_module_multilib == both


LOCAL_2ND_ARCH_VAR_PREFIX :=
include $(BUILD_SYSTEM)/module_arch_supported.mk

ifeq ($(my_module_arch_supported),true)
 include $(my_cuda_library_internal)
endif

ifdef TARGET_2ND_ARCH

 LOCAL_2ND_ARCH_VAR_PREFIX := $(TARGET_2ND_ARCH_VAR_PREFIX)
 include $(BUILD_SYSTEM)/module_arch_supported.mk

 ifeq ($(my_module_arch_supported),true)
  # Build for TARGET_2ND_ARCH
  OVERRIDE_BUILT_MODULE_PATH :=
  LOCAL_BUILT_MODULE :=
  LOCAL_INSTALLED_MODULE :=
  LOCAL_MODULE_STEM :=
  LOCAL_BUILT_MODULE_STEM :=
  LOCAL_INSTALLED_MODULE_STEM :=
  LOCAL_INTERMEDIATE_TARGETS :=

  include $(my_cuda_library_internal)
 endif

 LOCAL_2ND_ARCH_VAR_PREFIX :=
endif # TARGET_2ND_ARCH

my_module_arch_supported :=
my_cuda_library_internal :=

###########################################################
## Copy headers to the install tree
###########################################################
include $(BUILD_COPY_HEADERS)
include $(NVIDIA_POST)
