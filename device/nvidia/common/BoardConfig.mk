# Copyright (c) 2013-2015, NVIDIA CORPORATION.  All rights reserved.
# Build definitions common to all NVIDIA boards.

# If during build configuration setup i.e. during choosecombo or lunch or
# using $ANDROID_BUILD_TOP/buildspec.mk TARGET_PRODUCT is set to one of Nvidia
# boards then REFERENCE_DEVICE is the same as TARGET_DEVICE. For boards derived
# from NVIDIA boards, REFERENCE_DEVICE should be set to the NVIDIA reference
# device name in BoardConfig.mk or in the shell environment.

REFERENCE_DEVICE ?= $(TARGET_DEVICE)
TARGET_USES_PYTHON_IN_VENDOR := true

TARGET_RELEASETOOLS_EXTENSIONS := device/nvidia/common

ifeq ($(NV_ANDROID_FRAMEWORK_ENHANCEMENTS),TRUE)
ifeq ($(SECURE_OS_BUILD),tlk)
	# enable secure HDCP for secure OS build
	BOARD_VENDOR_HDCP_ENABLED ?= true
	BOARD_ENABLE_SECURE_HDCP ?= 1
	BOARD_VENDOR_HDCP_PATH ?= vendor/nvidia/tegra/tests-partner/hdcp
endif
endif

# SELinux policy for Android M or N
ifneq ($(PLATFORM_IS_AFTER_O_MR1),1)
BOARD_SEPOLICY_DIRS += device/nvidia/common/sepolicy_$(PLATFORM_VERSION_LETTER_CODE)
else
# SELinux policy after O
BOARD_SEPOLICY_DIRS += device/nvidia/common/sepolicy/common
endif
# NV_BUILD_GL_SUPPORT controls whether we build desktop OpenGL
# support into libglcore.so, i.e. eglBindAPI(EGL_OPENGL_API).
# EGL_OPENGL_API support requires Android framework modifications
# that are typically unavailable in partner builds
NV_BUILD_GL_SUPPORT ?= 1
ifeq ($(NV_EXPOSE_GLES_ONLY),true)
NV_BUILD_GL_SUPPORT := 0
endif

# If full OpenGL is built into the OS, then export the
# feature tag to Android, so that apps can filter on the
# feature in the Play Store
ifeq ($(NV_BUILD_GL_SUPPORT),1)
PRODUCT_COPY_FILES += \
    device/nvidia/common/com.nvidia.feature.opengl4.xml:system/etc/permissions/com.nvidia.feature.opengl4.xml
endif

ifeq ($(PLATFORM_IS_AFTER_N),1)
    TARGET_USES_HWC2 := true
endif
