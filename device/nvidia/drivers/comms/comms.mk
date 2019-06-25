#
# Copyright (c) 2015-2018, NVIDIA Corporation.  All Rights Reserved.
#
# NVIDIA Corporation and its licensors retain all intellectual property
# and proprietary rights in and to this software, related documentation
# and any modifications thereto.  Any use, reproduction, disclosure or
# distribution of this software and related documentation without an express
# license agreement from NVIDIA Corporation is strictly prohibited.
#

PRODUCT_PACKAGES += \
    hostapd \
    wpa_supplicant \
    wpa_supplicant.conf \
    libbt-vendor \
    libnvwifi-service

ifeq ($(PLATFORM_IS_AFTER_N),1)
PRODUCT_PACKAGES += \
    android.hardware.wifi@1.0-service \
    vendor.nvidia.hardware.bluetooth@1.0-impl \
    vendor.nvidia.hardware.bluetooth@1.0_vendor \
    libwpa_client \
    nvwifi \
    wificond \
    wifilogd

PRODUCT_MANIFEST += \
    device/nvidia/drivers/comms/commshal.xml
endif

PRODUCT_COPY_FILES += \
  frameworks/native/data/etc/android.hardware.wifi.xml:system/etc/permissions/android.hardware.wifi.xml \
  frameworks/native/data/etc/android.hardware.wifi.direct.xml:system/etc/permissions/android.hardware.wifi.direct.xml \
  frameworks/native/data/etc/android.hardware.bluetooth.xml:system/etc/permissions/android.hardware.bluetooth.xml \
  frameworks/native/data/etc/android.hardware.bluetooth_le.xml:system/etc/permissions/android.hardware.bluetooth_le.xml \
  frameworks/native/data/etc/android.hardware.location.xml:system/etc/permissions/android.hardware.location.xml \
  device/nvidia/common/wpa_supplicant.sh:system/bin/wpa_supplicant.sh

ifeq ($(NV_ANDROID_FRAMEWORK_ENHANCEMENTS), TRUE)
PRODUCT_COPY_FILES += \
  device/nvidia/common/bt_loader.sh:vendor/bin/bt_loader.sh \
  device/nvidia/common/wifi_loader.sh:vendor/bin/wifi_loader.sh \
  device/nvidia/common/supplicant_log_monitor.sh:vendor/bin/supplicant_log_monitor.sh
else
PRODUCT_COPY_FILES += \
  device/nvidia/common/bt_loader.sh.old:vendor/bin/bt_loader.sh \
  device/nvidia/common/wifi_loader.sh.old:vendor/bin/wifi_loader.sh \
  device/nvidia/common/supplicant_log_monitor.sh.old:vendor/bin/supplicant_log_monitor.sh
endif

ifeq ($(PLATFORM_IS_AFTER_N),1)
   PRODUCT_COPY_FILES += \
       device/nvidia/common/init.comms_o.rc:root/init.comms.rc
else
   PRODUCT_COPY_FILES += \
       device/nvidia/common/init.comms.rc:root/init.comms.rc
endif

# Copy wpa/p2p ovelay config files
PRODUCT_COPY_FILES += \
    hardware/broadcom/wlan/bcmdhd/config/wpa_supplicant_overlay.conf:system/etc/wifi/wpa_supplicant_overlay.conf \
    hardware/broadcom/wlan/bcmdhd/config/p2p_supplicant_overlay.conf:system/etc/wifi/p2p_supplicant_overlay.conf \
    device/nvidia/common/wifi_scan_config.conf:system/etc/wifi/wifi_scan_config.conf


#Copy product specific Wi-Fi low power channels config file
ifeq ($(findstring darcy, $(TARGET_PRODUCT)), darcy)
PRODUCT_COPY_FILES += \
    $(call add-to-product-copy-files-if-exists, device/nvidia/common/darcy_wifi_lp.conf:system/etc/wifi/wifi_lp.conf)
endif

ifneq ($(PLATFORM_IS_AFTER_O_MR1),1)
PRODUCT_PACKAGES += \
    idsmonitor
endif
