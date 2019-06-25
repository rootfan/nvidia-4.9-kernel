################################### tell Emacs this is a -*- makefile-gmake -*-
#
# Copyright (c) 2014, NVIDIA CORPORATION.  All rights reserved.
#
# NVIDIA CORPORATION and its licensors retain all intellectual property
# and proprietary rights in and to this software, related documentation
# and any modifications thereto.  Any use, reproduction, disclosure or
# distribution of this software and related documentation without an express
# license agreement from NVIDIA CORPORATION is strictly prohibited.
#
###############################################################################
#
# Convenience makefile fragment for generated header from tmake part umbrella
#
###############################################################################
#
# Generated headers only need to be generated during internal builds.
# These modules are always delivered as TMAKE_BINARY to the customer.
#
ifneq ($(NV_BUILD_TMAKE_CUSTOMER_BUILD),1)

LOCAL_MODULE_CLASS := ETC
LOCAL_MODULE_PATH  := $(TARGET_OUT_HEADERS)

include $(NVIDIA_TMAKE_PART)
else
include $(NVIDIA_POST_DUMMY)
endif # ifneq ($(NV_BUILD_TMAKE_CUSTOMER_BUILD),1)

# Local Variables:
# indent-tabs-mode: t
# tab-width: 8
# End:
# vi: set tabstop=8 noexpandtab:
