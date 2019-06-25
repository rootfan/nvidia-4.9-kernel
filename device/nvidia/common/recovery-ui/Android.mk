LOCAL_PATH := $(call my-dir)
include $(CLEAR_VARS)

LOCAL_C_INCLUDES += bootable/recovery
LOCAL_C_INCLUDES += external/libselinux/include
LOCAL_SRC_FILES := recovery_ui.cpp

LOCAL_STATIC_LIBRARIES := \
    libfs_mgr \
    libbase \
    libcutils \
    libminui

ifdef PLATFORM_IS_AFTER_O_MR0
LOCAL_STATIC_LIBRARIES += libziparchive
endif

ifeq ($(PLATFORM_IS_AFTER_N),1)
LOCAL_STATIC_LIBRARIES += libext4_utils
else
LOCAL_C_INCLUDES += system/extras
endif

# should match TARGET_RECOVERY_UI_LIB set in BoardConfig.mk
LOCAL_MODULE := librecovery_ui_default

ifeq ($(PLATFORM_IS_AFTER_LOLLIPOP),1)
LOCAL_CFLAGS += -DPLATFORM_IS_AFTER_LOLLIPOP=1
endif

ifeq ($(PLATFORM_IS_AFTER_M),1)
LOCAL_CFLAGS += -DPLATFORM_IS_AFTER_M=1
endif

ifeq ($(BOARD_SUPPORTS_BILLBOARD), true)
ifeq ($(PLATFORM_IS_AFTER_M),1)
LOCAL_CFLAGS += -DBOARD_SUPPORTS_BILLBOARD
ifeq ($(PLATFORM_IS_AFTER_N),1)
LOCAL_SRC_FILES += recovery_ui_billboard.cpp
endif

ifeq ($(PLATFORM_IS_AFTER_N),1)
LOCAL_STATIC_LIBRARIES += libpng_ndk
else
LOCAL_STATIC_LIBRARIES += libpng
endif
endif
endif

include $(BUILD_STATIC_LIBRARY)
