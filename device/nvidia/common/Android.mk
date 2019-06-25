LOCAL_PATH := $(call my-dir)

# init_tf.rc, based on secureos is enabled or disbaled
include $(NVIDIA_DEFAULTS)
ifeq ($(SECURE_OS_BUILD),tlk)
LOCAL_SRC_FILES := init.tlk.rc
LOCAL_MODULE := init.tlk
else
LOCAL_MODULE := init.tf
ifneq ($(filter tf y,$(SECURE_OS_BUILD)),)
LOCAL_SRC_FILES := init.tf_enabled.rc
else
LOCAL_SRC_FILES := init.tf_disabled.rc
endif
endif
LOCAL_MODULE_SUFFIX := .rc
LOCAL_MODULE_CLASS := ETC
LOCAL_MODULE_PATH := $(TARGET_ROOT_OUT)
include $(NVIDIA_PREBUILT)

# init.qvs.rc for qvs automation
include $(NVIDIA_DEFAULTS)
LOCAL_SRC_FILES := init.qvs.rc
LOCAL_MODULE := init.qvs
LOCAL_MODULE_SUFFIX := .rc
LOCAL_MODULE_CLASS := ETC
LOCAL_MODULE_PATH := $(TARGET_ROOT_OUT)
LOCAL_MODULE_TAGS := debug
include $(NVIDIA_PREBUILT)

# init.hdcp.rc
include $(NVIDIA_DEFAULTS)
LOCAL_SRC_FILES := init.hdcp.rc
LOCAL_MODULE := init.hdcp
LOCAL_MODULE_SUFFIX := .rc
LOCAL_MODULE_CLASS := ETC
LOCAL_MODULE_PATH := $(TARGET_ROOT_OUT)
include $(NVIDIA_PREBUILT)

# init.sata.configs.rc
include $(NVIDIA_DEFAULTS)
LOCAL_SRC_FILES := init.sata.configs.rc
LOCAL_MODULE := init.sata.configs
LOCAL_MODULE_SUFFIX := .rc
LOCAL_MODULE_CLASS := ETC
LOCAL_MODULE_PATH := $(TARGET_ROOT_OUT)
include $(NVIDIA_PREBUILT)

# init.nvphsd.rc
include $(NVIDIA_DEFAULTS)
LOCAL_SRC_FILES := init.nvphsd.rc
LOCAL_MODULE := init.nvphsd
LOCAL_MODULE_SUFFIX := .rc
LOCAL_MODULE_CLASS := ETC
LOCAL_MODULE_PATH := $(TARGET_ROOT_OUT)
include $(NVIDIA_PREBUILT)

# Install the host tool sdmmc_util.sh
include $(NVIDIA_DEFAULTS)
LOCAL_PREBUILT_EXECUTABLES := sdmmc_util.sh
include $(NVIDIA_HOST_PREBUILT)

include $(call all-makefiles-under,$(LOCAL_PATH))
