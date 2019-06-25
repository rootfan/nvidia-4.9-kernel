################################### tell Emacs this is a -*- makefile-gmake -*-
#
# Copyright (c) 2014-2016, NVIDIA CORPORATION.  All rights reserved.
#
# NVIDIA CORPORATION and its licensors retain all intellectual property
# and proprietary rights in and to this software, related documentation
# and any modifications thereto.  Any use, reproduction, disclosure or
# distribution of this software and related documentation without an express
# license agreement from NVIDIA CORPORATION is strictly prohibited.
#
###############################################################################
#
# Convenience makefile fragment for static library from tmake part umbrella
#
###############################################################################
#
# Static libraries only need to be generated during internal builds.
# These modules are always delivered as TMAKE_BINARY to the customer.
#
ifneq ($(NV_BUILD_TMAKE_CUSTOMER_BUILD),1)


###############################################################################
#
# Sanity checks for mandatory configuration variables
#
LOCAL_NVIDIA_TMAKE_STATIC_TYPE := $(strip $(LOCAL_NVIDIA_TMAKE_STATIC_TYPE))
ifeq ($(LOCAL_NVIDIA_TMAKE_STATIC_TYPE),)
  $(error $(LOCAL_PATH): LOCAL_NVIDIA_TMAKE_STATIC_TYPE is not defined)
endif


###############################################################################
#
# Static library type specific configuration
#
ifeq ($(LOCAL_NVIDIA_TMAKE_STATIC_TYPE),bootloader)
_tmake_static_subdir         := boot

else ifeq ($(LOCAL_NVIDIA_TMAKE_STATIC_TYPE),host)
LOCAL_IS_HOST_MODULE         := true
_tmake_static_subdir         := hostcc

else
  $(error $(LOCAL_PATH): tmake static library type  "$(LOCAL_NVIDIA_TMAKE_STATIC_TYPE)" is not supported)
endif


###############################################################################
#
# Common static library configuration
#
LOCAL_MODULE_CLASS               := STATIC_LIBRARIES
# LOCAL_MODULE_PATH set by caller
LOCAL_MODULE_SUFFIX              := .a
LOCAL_NVIDIA_TMAKE_PART_NAME     := static.$(LOCAL_NVIDIA_TMAKE_STATIC_TYPE)
LOCAL_NVIDIA_TMAKE_PART_ARTIFACT := prebuilt_static_libraries/$(_tmake_static_subdir)/$(LOCAL_MODULE)$(LOCAL_MODULE_SUFFIX)

# Rewrite local module name to mark it as tmake static library for release
LOCAL_MODULE                     := $(strip $(LOCAL_MODULE))_tmake_$(LOCAL_NVIDIA_TMAKE_STATIC_TYPE)

include $(NVIDIA_TMAKE_PART)


###############################################################################
#
# variable cleanup
#
_tmake_static_subdir :=

else
include $(NVIDIA_POST_DUMMY)
endif # ifneq ($(NV_BUILD_TMAKE_CUSTOMER_BUILD),1)

# Local Variables:
# indent-tabs-mode: t
# tab-width: 8
# End:
# vi: set tabstop=8 noexpandtab:
