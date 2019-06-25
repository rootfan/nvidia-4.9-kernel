###############################################################################
#
# Copyright (c) 2018 NVIDIA CORPORATION.  All Rights Reserved.
#
# NVIDIA CORPORATION and its licensors retain all intellectual property
# and proprietary rights in and to this software, related documentation
# and any modifications thereto.  Any use, reproduction, disclosure or
# distribution of this software and related documentation without an express
# license agreement from NVIDIA CORPORATION is strictly prohibited.
#
###############################################################################

# We're not defining LOCAL_PATH here because we can't safely override it when
# included from default.mk.
# When modifying this makefile, keept it agnostic to the value of LOCAL_PATH.
# LOCAL_PATH :=

ifndef BULLSEYE_LIBCOV_INCLUDED
    BULLSEYE_LIBCOV_INCLUDED := 1

    ifeq ($(BULLSEYE_COVERAGE_ENABLED),1)

        include $(NVIDIA_DEFAULTS)
        LOCAL_MODULE := libcov
        LOCAL_MODULE_CLASS := STATIC_LIBRARIES

        GEN_SRC := $(local-generated-sources-dir)/libcov-posix.c
        $(GEN_SRC): PRIVATE_CUSTOM_TOOL = $(ACP) $(BULLSEYE_ROOT)/run/libcov-posix.c $@
        $(GEN_SRC): $(ACP)
			$(transform-generated-source)

        LOCAL_GENERATED_SOURCES += $(GEN_SRC)
        LOCAL_C_INCLUDES += $(BULLSEYE_ROOT)/run

        include $(NVIDIA_STATIC_LIBRARY)


        include $(NVIDIA_DEFAULTS)
        LOCAL_MODULE := libcov_host
        LOCAL_MODULE_CLASS := STATIC_LIBRARIES
        LOCAL_IS_HOST_MODULE := true

        GEN_SRC := $(local-generated-sources-dir)/libcov-posix.c
        $(GEN_SRC): PRIVATE_CUSTOM_TOOL = $(ACP) $(BULLSEYE_ROOT)/run/libcov-posix.c $@
        $(GEN_SRC): $(ACP)
			$(transform-generated-source)

        LOCAL_GENERATED_SOURCES += $(GEN_SRC)
        LOCAL_C_INCLUDES += $(BULLSEYE_ROOT)/run

        include $(NVIDIA_HOST_STATIC_LIBRARY)
    endif

endif
