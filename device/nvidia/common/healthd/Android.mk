LOCAL_PATH:= $(call my-dir)

include $(NVIDIA_DEFAULTS)
LOCAL_NVIDIA_NO_COVERAGE := true

LOCAL_SRC_FILES:= healthd_board_tegra.cpp
LOCAL_SHARED_LIBRARIES += libbase

ifeq ($(PLATFORM_IS_AFTER_O_MR1),1)
LOCAL_HEADER_LIBRARIES += libhealthd_headers
else
  ifeq ($(PLATFORM_IS_AFTER_N),1)
  LOCAL_STATIC_LIBRARIES += libhealthd_android
  else
  LOCAL_STATIC_LIBRARIES += libhealthd.default
  endif
endif

LOCAL_MODULE:= libhealthd.tegra
include $(NVIDIA_STATIC_LIBRARY)

