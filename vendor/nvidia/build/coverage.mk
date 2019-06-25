#
# Coverage instrumentation support (Gcov and Bullseye)
#

# If coverage instrumentation is enabled through the environment variable
ifneq ($(NVIDIA_COVERAGE_ENABLED),)
# Gcov instrumentation was never setup for host components
ifneq ($(LOCAL_IS_HOST_MODULE),true)
# If instrumentation isn't disabled for the module
ifneq ($(LOCAL_NVIDIA_NO_COVERAGE),true)

# Instrument the code
LOCAL_CFLAGS += -fprofile-arcs -ftest-coverage

# If coverage output isn't disabled
ifneq ($(LOCAL_NVIDIA_NULL_COVERAGE),true)
LOCAL_LDFLAGS += -lgcc -lgcov
else	# !LOCAL_NVIDIA_NULL_COVERAGE
# Link to NULL-output libgcov
LOCAL_STATIC_LIBRARIES += libgcov_null
LOCAL_LDFLAGS += -Wl,--exclude-libs=libgcov_null
endif	# LOCAL_NVIDIA_NULL_COVERAGE

endif	# !LOCAL_NVIDIA_NO_COVERAGE
endif   # !LOCAL_IS_HOST_MODULE
endif	# NVIDIA_COVERAGE_ENABLED


ifeq ($(BULLSEYE_COVERAGE_ENABLED),1)
    ifneq ($(filter $(LOCAL_SDK_VERSION), 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20),)
        # The libc in old SDK versions misses some functions used by Bullseye's libcov
        $(warning $(LOCAL_MODULE_MAKEFILE): Bullseye needs at least LOCAL_SDK_VERSION 21, disabling coverage)
        LOCAL_NVIDIA_NO_COVERAGE := true
    endif

    ifneq ($(LOCAL_NVIDIA_NO_COVERAGE),true)
        ifeq ($(LOCAL_IS_HOST_MODULE),true)
            BULLSEYE_COV_DIR := $(HOST_OUT)
            BULLSEYE_LIBCOV := libcov_host
        else
            BULLSEYE_COV_DIR := $(PRODUCT_OUT)
            BULLSEYE_LIBCOV := libcov
        endif
        BULLSEYE_COVC_OPTIONS ?=
        BULLSEYE_COVC := $(BULLSEYE_ROOT)/bin/covc --no-banner --no-lib --srcdir $(ANDROID_BUILD_TOP) --select $(TEGRA_TOP)/ --file $(BULLSEYE_COV_DIR)/bullseye.cov $(BULLSEYE_COVC_OPTIONS)

        CC_WRAPPER := $(BULLSEYE_COVC)
        CXX_WRAPPER := $(BULLSEYE_COVC)

        LOCAL_C_INCLUDES += $(BULLSEYE_ROOT)/run

        ifneq ($(LOCAL_MODULE_CLASS),STATIC_LIBRARIES)
            LOCAL_STATIC_LIBRARIES += $(BULLSEYE_LIBCOV)
        endif

        # Disable warnings thrown by the instrumentation code
        # "-w" should be all we need, but some warnings are still seen in practice.
        LOCAL_CFLAGS += -w -Wno-self-assign -Wno-undef
        ifneq ($(LOCAL_CLANG),false)
            LOCAL_CFLAGS += -Wno-tautological-pointer-compare -Wno-pointer-bool-conversion -Wno-string-compare
        endif

        # Create a coverage stamp file and add it as a dependency of the component.
        # This allows us to track what components need a rebuild when resetting the
        # build time coverage data file created by Bullseye.
        BULLSEYE_STAMP_FILE := $(intermediates)/bullseye.stamp
        LOCAL_ADDITIONAL_DEPENDENCIES += $(BULLSEYE_STAMP_FILE)
        $(BULLSEYE_STAMP_FILE): PRIVATE_CUSTOM_TOOL = touch $@
        $(BULLSEYE_STAMP_FILE):
		    $(transform-generated-source)
    endif
endif
