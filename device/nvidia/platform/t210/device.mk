# NVIDIA Tegra6 "T132" development system
#
# Copyright (c) 2013-2018 NVIDIA Corporation.  All rights reserved.
#
# 32-bit specific product settings

$(call inherit-product-if-exists, frameworks/base/data/videos/VideoPackage2.mk)
$(call inherit-product, device/nvidia/platform/t210/device-common.mk)
$(call inherit-product, vendor/nvidia/tegra/core/android/t210/nvflash.mk)
$(call inherit-product, vendor/nvidia/tegra/core/android/touch/raydium.mk)
$(call inherit-product, vendor/nvidia/tegra/core/android/touch/sharp.mk)
$(call inherit-product, device/nvidia/platform/t210/motionq/motionq.mk)
$(call inherit-product, vendor/nvidia/tegra/core/android/multimedia/base.mk)
$(call inherit-product, vendor/nvidia/tegra/core/android/multimedia/firmware.mk)
$(call inherit-product, vendor/nvidia/tegra/core/android/camera/full.mk)
$(call inherit-product, vendor/nvidia/tegra/core/android/services/nvcpl.mk)
$(call inherit-product, vendor/nvidia/tegra/core/android/services/edid.mk)

ifneq ($(PLATFORM_IS_AFTER_O_MR1),1)
ifeq ($(NV_ANDROID_FRAMEWORK_ENHANCEMENTS),TRUE)
$(call inherit-product, vendor/nvidia/tegra/core/android/iva_sdk.mk)
endif
endif

JETPACK_ROOT ?= $(TEGRA_TOP)/jetpack-private/jetpack-current

#enable Widevine drm
PRODUCT_PROPERTY_OVERRIDES += drm.service.enabled=true
PRODUCT_PACKAGES += \
    com.google.widevine.software.drm.xml \
    com.google.widevine.software.drm \
    libdrmwvmplugin \
    libwvm \
    libWVStreamControlAPI_L1 \
    libwvdrm_L1

# Default OMX service to non-Treble
PRODUCT_PROPERTY_OVERRIDES += \
    persist.media.treble_omx=false

PRODUCT_COPY_FILES += \
   device/nvidia/platform/loki/t210/pbc.conf:system/etc/pbc.conf

PRODUCT_PACKAGES += \
    bpmp \
    tegra_xusb_firmware \
    tegra210b01_xusb_firmware \
    tegra21x_xusb_firmware

PRODUCT_PACKAGES += \
        tos \
        tlk_tos_t210b01 \
        tos_tzloader \
        trusty_tos \
        trusty_no_os \
        trusty_tos_t210b01 \
        storageproxyd \
        keystore.v0.tegra \
        keystore.v1.tegra \
        gatekeeper.tlk.tegra \
        gatekeeper.trusty.tegra \
        setup_fs \
        e2fsck \
        make_ext4fs \
        hdmi_cec.tegra \
        lights.tegra \
        pbc.tegra \
        power.tegra \
        power.loki_e \
        power.loki_e_lte \
        power.loki_e_wifi \
        power.darcy \
        power.foster_e \
        power.foster_e_hdd \
        libnvglsi \
        libnvwsi \
        libtos_nvtml \
        sc7entry-firmware

# PHS libraries
PRODUCT_PACKAGES += \
        libnvgov_boot \
        libnvgov_camera \
        libnvgov_force \
        libnvgov_generic \
        libnvgov_gpucompute \
        libnvgov_graphics \
        libnvgov_il \
        libnvgov_spincircle \
        libnvgov_tbc \
        libnvgov_ui \
        libnvphsd \
        libnvphs \

ifeq ($(PLATFORM_IS_AFTER_N),1)
PRODUCT_PACKAGES += \
        android.hardware.power-V1.0-java \
        vendor.nvidia.hardware.power@1.0 \
        vendor.nvidia.hardware.power@1.0-service \
        vendor.nvidia.hardware.power-V1.0-java \
        vendor.nvidia.hardware.keymanager@3.0-impl \
        vendor.nvidia.hardware.keymanager@3.0-service \
        android.hardware.tv.cec-V1.0-java \
        android.hardware.tv.cec@1.0-impl \
        android.hardware.tv.cec@1.0-service \
        powerhal.tegra \
        powerhal.tegra:32 \
        libnvcolorutil \
        vendor.nvidia.hardware.phs@1.0-impl \
        vendor.nvidia.hardware.phs@1.0 \
        libnvdc \
        vendor.nvidia.hardware.graphics.composer@1.0-service \
        vendor.nvidia.hardware.graphics.composer@1.0-impl \
        android.hardware.graphics.allocator@2.0-impl \
        android.hardware.graphics.allocator@2.0-service \
        android.hardware.graphics.mapper@2.0-impl \
        vendor.nvidia.hardware.graphics.display@1.0-impl \
		vendor.nvidia.hardware.nvwifi@1.0

ifneq ($(PLATFORM_IS_AFTER_O_MR1),1)
PRODUCT_PACKAGES += \
        Stats \
        NvShieldService
endif
endif

# HDCP SRM Support
PRODUCT_PACKAGES += \
        hdcp1x.srm \
        hdcp2x.srm \
        hdcp2xtest.srm

#enable Widevine drm
PRODUCT_PROPERTY_OVERRIDES += drm.service.enabled=true
PRODUCT_PACKAGES += \
    liboemcrypto \
    libdrmdecrypt

PRODUCT_RUNTIMES := runtime_libart_default

PRODUCT_PACKAGES += \
    gpload \
    ctload \
    c2debugger

#TegraOTA
PRODUCT_PACKAGES += \
    TegraOTA

ifneq ($(wildcard vendor/nvidia/tegra/core-private),)
PRODUCT_PACKAGES += \
    track.sh
endif

# Application for sending feedback to NVIDIA
PRODUCT_PACKAGES += \
    nvidiafeedback

# Paragon filesystem solution binaries
PRODUCT_PACKAGES += \
    mountufsd \
    chkufsd \
    mkexfat \
    chkexfat \
    mkhfs \
    chkhfs \
    mkntfs \
    chkntfs

#for SMD partition
PRODUCT_PACKAGES += \
    slot_metadata

# touch screen doesn't apply to Foster/Darcy
ifeq ($(filter foster_e% darcy% mdarcy% sif%, $(TARGET_PRODUCT)),)
# Sharp touch
PRODUCT_COPY_FILES += \
    device/nvidia/drivers/touchscreen/lr388k7_ts.idc:system/usr/idc/lr388k7_ts.idc \
    device/nvidia/common/init.sharp_touch.rc:root/init.sharp_touch.rc

# shield_platform_analyzer
$(call inherit-product-if-exists, vendor/nvidia/tegra/core/android/services/analyzer.mk)
endif

# blob
PRODUCT_PACKAGES += bmp

# Configure ALL T210 products using TLK to switch to using ATF as monitor
PRODUCT_USES_ARM_TF_MONITOR := true

#symlinks
PRODUCT_PACKAGES += gps.symlink

# Nvidia Camera app
ifeq ($(filter foster_e% darcy% mdarcy% sif%, $(TARGET_PRODUCT)),)
PRODUCT_PACKAGES += NvCamera
endif

ifneq ($(PLATFORM_IS_AFTER_N), 1)
# Vendor Interface Manifest
PRODUCT_COPY_FILES += \
     $(LOCAL_PATH)/manifest.xml:$(TARGET_COPY_OUT_VENDOR)/manifest.xml
endif
