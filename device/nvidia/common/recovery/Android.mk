LOCAL_PATH := $(call my-dir)

include $(NVIDIA_DEFAULTS)

ifeq ($(PLATFORM_IS_AFTER_N),1)
LOCAL_SRC_FILES := nv_recovery_updater_o.cpp
LOCAL_STATIC_LIBRARIES += \
    libselinux \
    libziparchive \
    libupdater \
    libedify \
    libotautil
else ifeq ($(PLATFORM_IS_AFTER_M),1)
LOCAL_SRC_FILES := nv_recovery_updater.cpp
LOCAL_STATIC_LIBRARIES += libselinux
else
LOCAL_SRC_FILES := nv_recovery_updater.c
endif
LOCAL_C_INCLUDES += bootable/recovery
LOCAL_STATIC_LIBRARIES += libfs_mgr

LOCAL_MODULE := libnvrecoveryupdater

LOCAL_NVIDIA_NO_WARNINGS_AS_ERRORS := 1
LOCAL_NVIDIA_NO_COVERAGE := true

include $(NVIDIA_STATIC_LIBRARY)
