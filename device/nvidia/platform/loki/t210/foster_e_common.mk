# NVIDIA Tegra7 "foster_e" development system
#
# Copyright (c) 2014-2018, NVIDIA Corporation.  All rights reserved.

## This is the file that is common for all Foster_e skus(foster_e_base, foster_e_hdd).

ifeq ($(PLATFORM_IS_AFTER_M),)
HOST_PREFER_32_BIT := true
endif

PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/media_profiles_foster_e.xml:system/etc/media_profiles.xml

PRODUCT_PACKAGES += \
    NvPeripheralService

ifeq ($(NV_ANDROID_FRAMEWORK_ENHANCEMENTS_AUDIO),TRUE)
PRODUCT_COPY_FILES += \
    device/nvidia/platform/loki/t210/audio_policy_foster.conf:system/etc/audio_policy.conf \
    frameworks/native/data/etc/android.hardware.audio.low_latency.xml:system/etc/permissions/android.hardware.audio.low_latency.xml \
    frameworks/native/data/etc/android.software.midi.xml:system/etc/permissions/android.software.midi.xml

else
PRODUCT_COPY_FILES += \
    device/nvidia/platform/t210/audio_policy_noenhance.conf:system/etc/audio_policy.conf \
    frameworks/native/data/etc/android.hardware.audio.low_latency.xml:system/etc/permissions/android.hardware.audio.low_latency.xml \
    frameworks/native/data/etc/android.software.midi.xml:system/etc/permissions/android.software.midi.xml
endif

PRODUCT_COPY_FILES += \
    device/nvidia/platform/loki/t210/nvaudio_conf_foster.xml:system/etc/nvaudio_conf.xml \
    device/nvidia/platform/loki/t210/audio_effects.conf:$(TARGET_COPY_OUT_VENDOR)/etc/audio_effects.conf \
    device/nvidia/platform/loki/t210/nvaudio_hdmi_drc.xml:system/etc/nvaudio_fx.xml


PRODUCT_COPY_FILES += \
	device/nvidia/common/init.nv_dev_board.usb.rc:root/init.nv_dev_board.usb.rc \
	device/nvidia/common/init.recovery.android.usb.rc:root/init.recovery.usb.rc

ifeq ($(NV_ANDROID_FRAMEWORK_ENHANCEMENTS),TRUE)
PRODUCT_COPY_FILES += device/nvidia/tegraflash/fac_rst_protection/disable_frp.bin:rp2.bin
endif

ifneq (,$(filter $(TARGET_BUILD_VARIANT),userdebug eng))
    ifneq ($(wildcard vendor/nvidia/loki/utils/otadiff),)
        PRODUCT_PACKAGES += \
	    otadiff_core \
	    otadiff_compare \
	    otadiff_config \
	    otadiff_device_whisperer \
	    otadiff_io \
	    otadiff.cfg \
	    otadiff.whitelist.cfg \
	    README \
	    split_bootimg \
	    extract-ikconfig
    endif

    PRODUCT_PACKAGES += \
        nvmemeater
endif

ifeq ($(PLATFORM_IS_AFTER_N), 1)
PRODUCT_COPY_FILES +=  \
    device/nvidia/platform/loki/permissions/com.nvidia.shieldnext.xml:$(TARGET_COPY_OUT_ODM)/etc/permissions/com.nvidia.shieldnext.xml \
    device/nvidia/platform/loki/permissions/privapp-permissions-nvidia.xml:$(TARGET_COPY_OUT_ODM)/etc/permissions/privapp-permissions-nvidia.xml
endif

# Genesys IO board with USB hub firmware bin for foster
LOCAL_FOSTER_GENESYS_FW_PATH=vendor/nvidia/foster/firmware/P1963-Genesys
PRODUCT_COPY_FILES += \
    $(call add-to-product-copy-files-if-exists, $(LOCAL_FOSTER_GENESYS_FW_PATH)/GL3521-latest.bin:$(TARGET_COPY_OUT_VENDOR)/firmware/GL3521_foster.bin) \
    $(call add-to-product-copy-files-if-exists, $(LOCAL_FOSTER_GENESYS_FW_PATH)/GL_latest.ini:$(TARGET_COPY_OUT_VENDOR)/firmware/GL_SS_HUB_ISP_foster.ini) \
    $(call add-to-product-copy-files-if-exists, vendor/nvidia/loki/utils/genesysload/geupdate.sh:$(TARGET_COPY_OUT_VENDOR)/bin/geupdate.sh)

PRODUCT_PACKAGES += \
    libtegra_sata_hal \
    rp3 \
    genesys_hub_update \
    sil_load \
    BluetoothMidiService \
    cac_log_dumper \
    rp4

TARGET_SYSTEM_PROP    += device/nvidia/platform/loki/t210/system.prop

HDCP_POLICY_CHECK := true

# this flag ensures that nvtml secure application doesn't get included in
# products like Jetson and customer builds. It is only required on SHIELD
USES_NVTML := true

# This flag allows the VRR TA to be built which enables the authentication
# with GSYNC sinks
USES_VRR := true

# FW check
LOCAL_FW_CHECK_TOOL_PATH=device/nvidia/common/fwcheck
LOCAL_FW_XML_PATH=vendor/nvidia/loki/skus
PRODUCT_COPY_FILES += $(call add-to-product-copy-files-if-exists, $(LOCAL_FW_XML_PATH)/fw_version.xml:$(TARGET_COPY_OUT_VENDOR)/etc/fw_version.xml) \
	$(call add-to-product-copy-files-if-exists, $(LOCAL_FW_CHECK_TOOL_PATH)/fw_check.py:fw_check.py)

PRODUCT_COPY_FILES += \
    device/nvidia/platform/loki/gpio_ir_recv.idc:system/usr/idc/gpio_ir_recv.idc

# Foster LED Firmware bin
LOCAL_FOSTER_LED_FW_PATH=vendor/nvidia/foster/firmware/P1961-Cypress/ReleasedHexFiles/Application
PRODUCT_COPY_FILES += \
    $(call add-to-product-copy-files-if-exists, $(LOCAL_FOSTER_LED_FW_PATH)/cypress_latest.cyacd:$(TARGET_COPY_OUT_VENDOR)/firmware/psoc_foster_fw.cyacd)

# cypress updater
PRODUCT_COPY_FILES += \
    $(call add-to-product-copy-files-if-exists, vendor/nvidia/tegra/core-private/utils/cyload/cyupdate.sh:$(TARGET_COPY_OUT_VENDOR)/bin/cyupdate.sh) \
    $(call add-to-product-copy-files-if-exists, vendor/nvidia/loki/utils/cyload/cyupdate_config.sh:$(TARGET_COPY_OUT_VENDOR)/bin/cyupdate_config.sh)

PRODUCT_PROPERTY_OVERRIDES += \
    ro.hdmi.wake_on_hotplug = 0

## Sensor package definition
include device/nvidia/platform/loki/t210/sensors-foster_e.mk
# The following build variables are defined in 'sensors-[platform].mk' file:
#	SENSOR_BUILD_VERSION
#	SENSOR_BUILD_FLAGS
#	SENSOR_FUSION_VENDOR
#	SENSOR_FUSION_VERSION
#	SENSOR_FUSION_BUILD_DIR
#	SENSOR_HAL_API
#	SENSOR_HAL_VERSION
#	SENSOR_HAL_HAL_OS_INTERFACE_SRC
#	SENSOR_HAL_LOCAL_DRIVER_SRC
#	PRODUCT_PROPERTY_OVERRIDES
#	PRODUCT_PACKAGES

# Wi-Fi country code system properties
PRODUCT_PROPERTY_OVERRIDES += \
    ro.factory.wifi=/factory/wifi_config \
    ro.factory.wifi.lbs=true

# Define Netflix nrdp properties
PRODUCT_COPY_FILES += device/nvidia/platform/loki/t210/nrdp.modelgroup.xml:system/etc/permissions/nrdp.modelgroup.xml

# nDiscovery
PRODUCT_COPY_FILES += $(LOCAL_PATH)/../../../common/init.ndiscovery.rc:root/init.ndiscovery.rc

# Include vendor HAL definitions
ifeq ($(PLATFORM_IS_AFTER_N),1)
include device/nvidia/platform/t210/fosterhal.mk
endif

PRODUCT_PROPERTY_OVERRIDES += \
    ro.product.first_api_level=21

# Test binaries for FactorySysChecker
PRODUCT_PACKAGES += \
    check_eks \
    dx_provTest \
    testapp_vrr \
    eks_hdcprx \
    FactorySysChecker \
    factory_tests

# Get rid of dex preoptimization
FOSTER_E_DONT_DEXPREOPT_MODULES := \
    AtvRemoteService
$(call add-product-dex-preopt-module-config,$(FOSTER_E_DONT_DEXPREOPT_MODULES),disable)

# Android N enabled DEXPREOPT by default, but we just want it for user image to keep consistent behavior with M
ifeq ($(HOST_OS),linux)
  ifneq ($(TARGET_BUILD_VARIANT),user)
    WITH_DEXPREOPT := false
  endif
  # Android P requires non eng linux builds must have preopt enabled so that system server doesn't run as interpreter
  ifeq ($(PLATFORM_IS_AFTER_O_MR1),1)
    ifeq (,$(filter eng, $(TARGET_BUILD_VARIANT)))
      WITH_DEXPREOPT_BOOT_IMG_AND_SYSTEM_SERVER_ONLY := true
    endif
  endif
endif

# Always disable DEXPREOPT on Sif platform to save space
ifneq ($(filter sif%, $(TARGET_PRODUCT)),)
  WITH_DEXPREOPT := false
  # Android P requires non eng linux builds must have preopt enabled so that system server doesn't run as interpreter
  ifeq ($(PLATFORM_IS_AFTER_O_MR1),1)
    ifeq (,$(filter eng, $(TARGET_BUILD_VARIANT)))
      WITH_DEXPREOPT_BOOT_IMG_AND_SYSTEM_SERVER_ONLY := true
    endif
  endif
endif

# Get rid of dex preoptimization
FOSTER_E_DONT_DEXPREOPT_MODULES := \
    AtvLatinIME \
    AVSync \
    BlakePairing \
    FrostManager \
    Gallery2 \
    GoogleCalendarSyncAdapter \
    GoogleContactsSyncAdapter \
    GoogleTTS \
    Katniss \
    Music2Pano \
    Netflix \
    NoTouchAuthDelegate \
    NvAccStService \
    NvAndroidOSC \
    NvCecService \
    NvCPLSvc \
    NvCPLUpdater \
    NvFactoryHelper \
    NvGamecast \
    NvHDMIMonitorService \
    nvidiafeedback \
    NvIgnition \
    NvIRTuner \
    NvPeripheralService \
    NvShieldService \
    NvXtraMedia \
    NvXtraMedia2 \
    NvXtraMediaV \
    OverscanComp \
    PlayGamesPano \
    Plex \
    PlexMediaServer \
    PrebuiltShieldRemoteService \
    PrintSpooler \
    Ps3UsbPairer \
    QuadDSecurityService \
    Stats \
    TegraZone_Next \
    VideosPano \
    Welcome \
    YouTubeLeanback
$(call add-product-dex-preopt-module-config,$(FOSTER_E_DONT_DEXPREOPT_MODULES),disable)
