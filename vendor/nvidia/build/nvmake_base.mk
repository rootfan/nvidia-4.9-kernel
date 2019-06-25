ifneq ($(filter-out EXECUTABLES SHARED_LIBRARIES,$(LOCAL_MODULE_CLASS)),)
$(error The integration layer for the nvmake build system supports executables and shared libraries only)
endif

include $(NVIDIA_NVMAKE_CLEAR)
include $(NVIDIA_BASE)
# Including coverage.mk for LDFLAGS. For GPU builds the CFLAGS are set in:
# $(NV_GPUDRV_SOURCE)/drivers/common/build/gcc-x.x.x-android.nvmk
include $(NVIDIA_COVERAGE)

# Set to 0 to do nvmake builds without the unix-build chroot.
# This requires the same tools present in the chroot to be installed on the
# system, some of which may not be readily available in Ubuntu.
NV_USE_UNIX_BUILD ?= 1

NVIDIA_NVMAKE_BUILD_TYPE := $(TARGET_BUILD_TYPE)
ifdef DEBUG_MODULE_$(strip $(LOCAL_MODULE))
  NVIDIA_NVMAKE_BUILD_TYPE := debug
endif

NVIDIA_NVMAKE_MODULE_NAME := $(LOCAL_MODULE)

ifeq ($(LOCAL_NVIDIA_NVMAKE_TREE),drv)
  NVIDIA_NVMAKE_TOP := $(NV_GPUDRV_SOURCE)
else
  NVIDIA_NVMAKE_TOP := $(TEGRA_TOP)/gpu/$(LOCAL_NVIDIA_NVMAKE_TREE)
endif
NVIDIA_NVMAKE_TOP := $(abspath $(NVIDIA_NVMAKE_TOP))

ifeq ($(LOCAL_NVIDIA_NVMAKE_EXTERNAL_DRIVER_TREE),drv)
  NVIDIA_NVMAKE_EXTERNAL_DRIVER_SOURCE := $(NV_GPUDRV_SOURCE)
else
  ifneq ($(LOCAL_NVIDIA_NVMAKE_EXTERNAL_DRIVER_TREE),)
    NVIDIA_NVMAKE_EXTERNAL_DRIVER_SOURCE := $(TEGRA_TOP)/gpu/$(LOCAL_NVIDIA_NVMAKE_EXTERNAL_DRIVER_TREE)
  else
    NVIDIA_NVMAKE_EXTERNAL_DRIVER_SOURCE :=
  endif
endif
NVIDIA_NVMAKE_EXTERNAL_DRIVER_SOURCE := $(abspath $(NVIDIA_NVMAKE_EXTERNAL_DRIVER_SOURCE))

NVIDIA_NVMAKE_UNIX_BUILD_COMMAND := \
  unix-build \
  --no-devrel \
  --extra $(ANDROID_BUILD_TOP) \
  --extra $(P4ROOT)/sw/tools \
  --tools $(P4ROOT)/sw/tools \
  --source $(NVIDIA_NVMAKE_TOP) \
  --extra-with-bind-point $(P4ROOT)/sw/mobile/tools/linux/android/nvmake/unix-build64/lib /lib \
  --extra-with-bind-point $(P4ROOT)/sw/mobile/tools/linux/android/nvmake/unix-build64/lib32 /lib32 \
  --extra-with-bind-point $(P4ROOT)/sw/mobile/tools/linux/android/nvmake/unix-build64/lib64 /lib64 \
  --extra $(P4ROOT)/sw/mobile/tools/linux/android/nvmake \
  --extra /proc

NVIDIA_NVMAKE_MODULE_PRIVATE_PATH := $(LOCAL_NVIDIA_NVMAKE_OVERRIDE_MODULE_PRIVATE_PATH)

ifneq ($(strip $(SHOW_COMMANDS)),)
  NVIDIA_NVMAKE_VERBOSE := NV_VERBOSE=1
else
  NVIDIA_NVMAKE_VERBOSE := -s NV_LOG_REL_TO_OUTPUTDIR=1
endif

# Enable guardword for release builds and external profile
ifneq ($(NV_INTERNAL_PROFILE),1)
ifeq ($(NVIDIA_NVMAKE_BUILD_TYPE),release)
# Disable guardword checks in the gcov code coverage build - gcov
# build adds some symbols that don't pass this check thus breaking the
# gcov build.
ifeq ($(NVIDIA_COVERAGE_ENABLED),)
NVIDIA_NVMAKE_GUARDWORD := NV_GUARDWORD=1
endif
endif
endif

# extra definitions to pass to nvmake
NVIDIA_NVMAKE_EXTRADEFS := NV_SYMBOLS=1 NV_SEPARATE_DEBUG_INFO= NV_STRIP= NV_DISABLE_EARLY_GUARDWORD_CHECK=1
NVIDIA_NVMAKE_EXTRADEFS += PLATFORM_IS_AFTER_LOLLIPOP=$(PLATFORM_IS_AFTER_LOLLIPOP)
ifdef PLATFORM_IS_AFTER_M
NVIDIA_NVMAKE_EXTRADEFS += PLATFORM_IS_AFTER_M=$(PLATFORM_IS_AFTER_M)
endif
ifdef PLATFORM_IS_AFTER_N
NVIDIA_NVMAKE_EXTRADEFS += PLATFORM_IS_AFTER_N=$(PLATFORM_IS_AFTER_N)
endif
ifdef PLATFORM_IS_AFTER_O_MR0
NVIDIA_NVMAKE_EXTRADEFS += PLATFORM_IS_AFTER_O_MR0=$(PLATFORM_IS_AFTER_O_MR0)
endif
ifdef PLATFORM_IS_AFTER_O_MR1
NVIDIA_NVMAKE_EXTRADEFS += PLATFORM_IS_AFTER_O_MR1=$(PLATFORM_IS_AFTER_O_MR1)
endif

# We always link nvmake components against these few libraries.
LOCAL_SHARED_LIBRARIES += libc libdl libm libz liblog
ifeq ($(LOCAL_SDK_VERSION)$(LOCAL_USE_VENDOR_GNUSTL),)
LOCAL_SHARED_LIBRARIES += libc++
endif

#
# guardword post install
#
# This only works for drv tree, apps-graphic is not in this yet
#
ifneq ($(NVIDIA_NVMAKE_BUILD_TYPE),release)
  LOCAL_NVIDIA_NVMAKE_GUARDWORD_CHECK := false
endif

ifneq ($(LOCAL_NVIDIA_NVMAKE_GUARDWORD_CHECK), false)
  ifeq ($(NVIDIA_COVERAGE_ENABLED),)
    # setup parameters for NV_CHECK_GUARDWORDS_CMD
    ifneq ($(strip $(SHOW_COMMANDS)),)
      NVIDIA_NVMAKE_VERBOSE_PARAM := 1
    endif
    NV_CHECK_GUARDWORDS_OUTPUTDIR = $(NVIDIA_NVMAKE_OUTPUT)
    NV_CHECK_GUARDWORDS_PATH = $(NVIDIA_NVMAKE_TOP)/drivers/common/build
    NV_CHECK_GUARDWORDS_VERBOSE = $(NVIDIA_NVMAKE_VERBOSE_PARAM)
    NV_CHECK_GUARDWORDS_PYTHON = python
    include $(NVIDIA_NVMAKE_TOP)/drivers/common/build/nvGuardword.mk
    ifdef LOCAL_POST_INSTALL_CMD
      ifeq ($(flavor LOCAL_POST_INSTALL_CMD),recursive)
        LOCAL_POST_INSTALL_CMD += &&
      else
        # convert from simple to recursive variable
        LOCAL_POST_INSTALL_CMD = $(LOCAL_POST_INSTALL_CMD) &&
      endif
    else
      LOCAL_POST_INSTALL_CMD =
    endif
    LOCAL_POST_INSTALL_CMD += $(call NV_CHECK_GUARDWORDS_CMD,$(LOCAL_INSTALLED_MODULE))
  endif
endif

