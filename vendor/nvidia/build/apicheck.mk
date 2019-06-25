# Inputs:
#   LOCAL_MODULE
#   LOCAL_2ND_ARCH_VAR_PREFIX
#   LOCAL_PROPRIETARY_MODULE
#   LOCAL_NVIDIA_EXPORTS
#
# This makefile saves and restores LOCAL_MODULE, any other variable is the
# responsiblity of the caller

# The apicheck relies on linking an executable against the shared library.
# If we use a library without the "lib" prefix in LOCAL_SHARED_LIBRARIES, the
# build system doesn't handle it properly and we get a linker failure.
ifeq ($(filter lib%,$(LOCAL_MODULE)),)
$(error $(LOCAL_MODULE_MAKEFILE): apicheck only supported on shared libraries named with a "lib" prefix)
endif

NVIDIA_CHECK_MODULE := $(LOCAL_MODULE)
NVIDIA_2ND_ARCH_VAR_PREFIX := $(LOCAL_2ND_ARCH_VAR_PREFIX)
NVIDIA_PROPRIETARY_MODULE := $(LOCAL_PROPRIETARY_MODULE)

include $(CLEAR_VARS)

LOCAL_MODULE := $(NVIDIA_CHECK_MODULE)_apicheck
ifneq ($(NVIDIA_2ND_ARCH_VAR_PREFIX),)
LOCAL_MODULE := $(NVIDIA_CHECK_MODULE)_apicheck$(TARGET_2ND_ARCH_MODULE_SUFFIX)
endif
LOCAL_PROPRIETARY_MODULE := $(NVIDIA_PROPRIETARY_MODULE)

LOCAL_MODULE_CLASS := EXECUTABLES
LOCAL_MODULE_PATH := $(call local-intermediates-dir,,$(NVIDIA_2ND_ARCH_VAR_PREFIX))/CHECK

ifneq ($(NVIDIA_2ND_ARCH_VAR_PREFIX),)
LOCAL_MULTILIB := 32
else
LOCAL_MULTILIB := first
endif

# apicheck binaries aren't meant to be executed, don't track code coverage.
LOCAL_NVIDIA_NO_COVERAGE := true

# WAR bug 1615476: Disable transitive dependency on shared libraries.
# For some reason this is not the default in the AARCH64 toolchain. This workaround can be removed
# once the toolchain is fixed, or the following patch makes it into Android releases:
# https://android.googlesource.com/platform/build/+/cf6f808408fa69d6643fed5a38758cbf22f3b0c0
LOCAL_LDFLAGS += -Wl,--allow-shlib-undefined

$(eval $(call nvidia-generate-code-from-exports,$(LOCAL_NVIDIA_EXPORTS),-apicheck,check.c))

LOCAL_GENERATED_SOURCES += $(GEN)
LOCAL_SHARED_LIBRARIES := $(NVIDIA_CHECK_MODULE)
include $(BUILD_EXECUTABLE)

# The build system automatically creates install dependencies from the apicheck
# to shared libraries it depends on. Drop them, apicheck executables are not
# installed on the file system, and we end up with circular dependencies
# (the shared library depends on the apicheck).
$(NVIDIA_2ND_ARCH_VAR_PREFIX)TARGET_DEPENDENCIES_ON_SHARED_LIBRARIES := \
  $(filter-out $(LOCAL_MODULE):%,$($(NVIDIA_2ND_ARCH_VAR_PREFIX)TARGET_DEPENDENCIES_ON_SHARED_LIBRARIES))

# restore some of the variables for potential further use in caller
LOCAL_MODULE := $(NVIDIA_CHECK_MODULE)

# Clear used variables
NVIDIA_CHECK_MODULE :=
NVIDIA_2ND_ARCH_VAR_PREFIX :=
NVIDIA_PROPRIETARY_MODULE :=
