TARGET_BOARD_PLATFORM := tegra
TARGET_TEGRA_VERSION := t210
TARGET_TEGRA_FAMILY := t21x

# 64-bit CPU options
TARGET_CPU_ABI := arm64-v8a
TARGET_CPU_ABI2 :=
TARGET_CPU_SMP := true
TARGET_CPU_VARIANT := generic
TARGET_ARCH := arm64
TARGET_ARCH_VARIANT := armv8-a

TARGET_2ND_ARCH := arm
TARGET_2ND_ARCH_VARIANT := armv7-a-neon
TARGET_2ND_CPU_VARIANT := cortex-a15
TARGET_2ND_CPU_ABI := armeabi-v7a
TARGET_2ND_CPU_ABI2 := armeabi

# malloc on 16-byte boundary
BOARD_MALLOC_ALIGNMENT := 16

TARGET_USES_64_BIT_BINDER := true

BOARD_BUILD_BOOTLOADER := false

TARGET_USE_DTB := true

BOARD_USES_GENERIC_AUDIO := false
BOARD_USES_ALSA_AUDIO := true

ifeq ($(PLATFORM_IS_AFTER_N), 1)
USE_CUSTOM_AUDIO_POLICY := 0
#Below flag to be set when HIDL resources are not included
#USE_LEGACY_LOCAL_AUDIO_HAL := true
else
ifeq ($(NV_ANDROID_FRAMEWORK_ENHANCEMENTS_AUDIO), TRUE)
USE_CUSTOM_AUDIO_POLICY := 1
else
USE_CUSTOM_AUDIO_POLICY := 0
endif
endif

TARGET_USERIMAGES_USE_EXT4 := true
BOARD_FLASH_BLOCK_SIZE := 4096

USE_E2FSPROGS := true
USE_OPENGL_RENDERER := true

# Allow this variable to be overridden to n for non-secure OS build
SECURE_OS_BUILD ?= y
ifeq ($(SECURE_OS_BUILD),y)
    SECURE_OS_BUILD := tlk
endif

#Enable Code Coverage related variables
ifeq ($(NV_BUILD_CONFIGURATION_IS_COVERAGE),1)
ENABLE_MULTIMEDIA_CODE_COVERAGE := 1
else
ENABLE_MULTIMEDIA_CODE_COVERAGE := 0
endif
# Uncomment below line to use Nvidia's GPU-accelerated RS driver by default
# OVERRIDE_RS_DRIVER := libnvRSDriver.so

ifeq ($(PLATFORM_IS_AFTER_O_MR1),1)
# ignore neverallow rule for P during bringup
SELINUX_IGNORE_NEVERALLOWS := true
PRODUCT_SEPOLICY_SPLIT := true
PRODUCT_SEPOLICY_SPLIT_OVERRIDE := true
PRODUCT_ENFORCE_VINTF_MANIFEST := true
PRODUCT_ENFORCE_VINTF_MANIFEST_OVERRIDE := true
PRODUCT_NOTICE_SPLIT := true
endif

include device/nvidia/common/BoardConfig.mk

# BOARD_WIDEVINE_OEMCRYPTO_LEVEL
# The security level of the content protection provided by the Widevine DRM plugin depends
# on the security capabilities of the underlying hardware platform.
# There are Level 1/2/3. To run HD contents, should be Widevine level 1 security.
BOARD_WIDEVINE_OEMCRYPTO_LEVEL := 1
