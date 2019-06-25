#
# Copyright (c) 2016, NVIDIA CORPORATION.  All rights reserved.
#
# Template for host unit tests
#
# Builds the test as host executable.
# Executes the test at compile time in one-shot makefile builds ("mm", "mmm") only,
# if the test or a dependency changed since last execution.
#
# We restrict to one-shot makefiles to ensure that intermittently failing tests
# do not affect developers' and Buildbrain's ability to produce an Android image.
#
# This template only supports tests that return a non-zero error code on failure.

LOCAL_MODULE_TAGS := nvidia_tests

include $(NVIDIA_HOST_EXECUTABLE)

# Code under here is not executed in Buildbrain, please carefully validate locally.
ifneq ($(ONE_SHOT_MAKEFILE),)
    # Trivially supported, not executed in modular builds.
    NVIDIA_TEMPLATE_SUPPORTS_BUILD_MODULARIZATION := true

    _nvidia_unit_test_name := $(LOCAL_MODULE)
    _nvidia_unit_test_parameters := $(LOCAL_NVIDIA_UNIT_TEST_PARAMETERS)

    # Run the test by making its log file one of the targets to build.
    # This is adapted from the PHONY_PACKAGE implementation.
    include $(NVIDIA_DEFAULTS)

    LOCAL_MODULE_CLASS := FAKE
    LOCAL_MODULE := $(_nvidia_unit_test_name).log

    include $(BUILD_SYSTEM)/base_rules.mk

    # Rule to run the test silently and generate a log file.
    # Display the log file on failure, before make deletes it.
    $(LOCAL_BUILT_MODULE): PRIVATE_NVIDIA_UNIT_TEST_PARAMETERS := $(_nvidia_unit_test_parameters)
    $(LOCAL_BUILT_MODULE): $(HOST_OUT_EXECUTABLES)/$(_nvidia_unit_test_name) $(LOCAL_MODULE_MAKEFILE) $(LOCAL_ADDITIONAL_DEPENDENCIES)
		@echo Run unit test: $< $(PRIVATE_NVIDIA_UNIT_TEST_PARAMETERS) ">" $@ "2>&1"
		$(hide) mkdir -p $(dir $@)
		$(hide) $< $(PRIVATE_NVIDIA_UNIT_TEST_PARAMETERS) > $@ 2>&1 || { cat $@; exit 1; }

    include $(NVIDIA_BASE)
    include $(NVIDIA_POST)

    _nvidia_unit_test_name :=
    _nvidia_unit_test_parameters :=
endif
