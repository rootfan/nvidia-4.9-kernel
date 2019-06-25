# NVIDIA Tegra development system
#
# Copyright (c) 2013-2018 NVIDIA Corporation.  All rights reserved.
#
# Common 32/64-bit userspace options

include frameworks/native/build/tablet-10in-xhdpi-2048-dalvik-heap.mk
include $(LOCAL_PATH)/../../drivers/comms/comms.mk
include $(LOCAL_PATH)/lkm/lkm.mk
include $(TEGRA_TOP)/core/android/services/utils.mk
-include $(TEGRA_TOP)/bct/t210/bct.mk
include $(LOCAL_PATH)/../../common/graphics/graphics.mk

PRODUCT_AAPT_CONFIG += mdpi hdpi xhdpi

DEVICE_ROOT := device/nvidia

NVFLASH_FILES_PATH := $(DEVICE_ROOT)/tegraflash/t210

PRODUCT_COPY_FILES += \
    $(NVFLASH_FILES_PATH)/eks_nokey.dat:eks.dat \
    $(NVFLASH_FILES_PATH)/flash_t210_android_sdmmc.xml:flash_t210_android_sdmmc.xml \
    $(NVFLASH_FILES_PATH)/flash_t210_android_sata.xml:flash_t210_android_sata.xml \
    $(NVFLASH_FILES_PATH)/flash_t210_android_sata_fb.xml:flash_t210_android_sata_fb.xml \
    $(NVFLASH_FILES_PATH)/flash_t210_android_sdmmc_diag.xml:flash_t210_android_sdmmc_diag.xml \
    $(NVFLASH_FILES_PATH)/flash_t210_android_sata_diag.xml:flash_t210_android_sata_diag.xml \
    $(NVFLASH_FILES_PATH)/flash_t210_android_sdmmc_fb_diag.xml:flash_t210_android_sdmmc_fb_diag.xml \
    $(NVFLASH_FILES_PATH)/flash_t210_android_sata_fb_diag.xml:flash_t210_android_sata_fb_diag.xml \
    $(NVFLASH_FILES_PATH)/flash_t210b01_android_sdmmc.xml:flash_t210b01_android_sdmmc.xml \
    $(NVFLASH_FILES_PATH)/flash_t210b01_android_sdmmc_fb.xml:flash_t210b01_android_sdmmc_fb.xml

ifeq ($(NVIDIA_KERNEL_COVERAGE_ENABLED),1)
PRODUCT_COPY_FILES += \
    $(NVFLASH_FILES_PATH)/partition_tables/darcy/flash_t210_darcy_gcov_android_sdmmc.xml:flash_t210_darcy_android_sdmmc.xml \
    $(NVFLASH_FILES_PATH)/partition_tables/darcy/flash_t210b01_darcy_gcov_android_sdmmc.xml:flash_t210b01_darcy_android_sdmmc.xml \
    $(NVFLASH_FILES_PATH)/partition_tables/sif/flash_t210b01_sif_gcov_android_sdmmc.xml:flash_t210b01_sif_android_sdmmc.xml
else
PRODUCT_COPY_FILES += \
    $(NVFLASH_FILES_PATH)/partition_tables/darcy/flash_t210_darcy_android_sdmmc.xml:flash_t210_darcy_android_sdmmc.xml \
    $(NVFLASH_FILES_PATH)/partition_tables/darcy/flash_t210b01_darcy_android_sdmmc.xml:flash_t210b01_darcy_android_sdmmc.xml \
    $(NVFLASH_FILES_PATH)/partition_tables/sif/flash_t210b01_sif_android_sdmmc.xml:flash_t210b01_sif_android_sdmmc.xml
endif

ifneq ($(filter t210ref%,$(TARGET_PRODUCT)),)
PRODUCT_COPY_FILES += \
    $(NVFLASH_FILES_PATH)/partition_tables/jetson/flash_t210_jetson_android_sdmmc.xml:flash_t210_android_sdmmc_fb.xml
else
PRODUCT_COPY_FILES += \
    $(NVFLASH_FILES_PATH)/flash_t210_android_sdmmc_fb.xml:flash_t210_android_sdmmc_fb.xml
endif

NVFLASH_FILES_PATH :=

PRODUCT_COPY_FILES += \
    frameworks/native/data/etc/android.hardware.hdmi.cec.xml:system/etc/permissions/android.hardware.hdmi.cec.xml \
    frameworks/native/data/etc/android.hardware.usb.host.xml:system/etc/permissions/android.hardware.usb.host.xml \
    frameworks/native/data/etc/android.hardware.usb.accessory.xml:system/etc/permissions/android.hardware.usb.accessory.xml

PRODUCT_COPY_FILES += \
    $(call add-to-product-copy-files-if-exists,frameworks/native/data/etc/android.hardware.ethernet.xml:system/etc/permissions/android.hardware.ethernet.xml) \
    $(call add-to-product-copy-files-if-exists, $(LOCAL_PATH)/js_firmware.bin:vendor/firmware/js_firmware.bin) \
    $(call add-to-product-copy-files-if-exists, $(LOCAL_PATH)/ct_firmware.bin:vendor/firmware/ct_firmware.bin)

ifneq ($(TARGET_BUILD_VARIANT), user)
    PRODUCT_COPY_FILES += \
        $(call add-to-product-copy-files-if-exists, vendor/nvidia/tegra/tests-partner/cec/cecutil:$(TARGET_COPY_OUT_VENDOR)/bin/cecutil)
endif

PRODUCT_COPY_FILES += \
  $(LOCAL_PATH)/ueventd.t210ref.rc:root/ueventd.e2190.rc \
  $(LOCAL_PATH)/ueventd.t210ref.rc:root/ueventd.e2220.rc \
  $(LOCAL_PATH)/ueventd.t210ref.rc:root/ueventd.e3350.rc \
  $(LOCAL_PATH)/ueventd.t210ref.rc:root/ueventd.jetson_e.rc \
  $(LOCAL_PATH)/ueventd.t210ref.rc:root/ueventd.jetson_cv.rc \
  $(LOCAL_PATH)/ueventd.t210ref.rc:root/ueventd.t18x-interposer.rc \
  $(LOCAL_PATH)/ueventd.t210ref.rc:root/ueventd.loki_e_lte.rc \
  $(LOCAL_PATH)/ueventd.t210ref.rc:root/ueventd.loki_e_wifi.rc \
  $(LOCAL_PATH)/ueventd.t210ref.rc:root/ueventd.loki_e_base.rc \
  $(LOCAL_PATH)/ueventd.t210ref.rc:root/ueventd.foster_e.rc \
  $(LOCAL_PATH)/ueventd.t210ref.rc:root/ueventd.foster_e_hdd.rc \
  $(LOCAL_PATH)/ueventd.t210ref.rc:root/ueventd.darcy.rc \
  $(LOCAL_PATH)/ueventd.t210ref.rc:root/ueventd.sif.rc \
  $(LOCAL_PATH)/ueventd.abca.rc:root/ueventd.abca.rc \
  $(LOCAL_PATH)/ueventd.abca.rc:root/ueventd.abcb.rc \
  $(LOCAL_PATH)/tegra-kbc.kl:system/usr/keylayout/tegra-kbc.kl \
  device/nvidia/platform/loki/Vendor_0955_Product_7205.kl:system/usr/keylayout/Vendor_0955_Product_7205.kl \
  device/nvidia/platform/loki/Vendor_0955_Product_7210.kl:system/usr/keylayout/Vendor_0955_Product_7210.kl \
  device/nvidia/platform/loki/Vendor_0955_Product_7214.kl:system/usr/keylayout/Vendor_0955_Product_7214.kl \
  device/nvidia/platform/loki/Vendor_0955_Product_7217.kl:system/usr/keylayout/Vendor_0955_Product_7217.kl \
  device/nvidia/platform/loki/Vendor_0955_Product_7210.idc:system/usr/idc/Vendor_0955_Product_7210.idc \
  device/nvidia/platform/loki/Vendor_0955_Product_7212.idc:system/usr/idc/Vendor_0955_Product_7212.idc \
  device/nvidia/platform/loki/Vendor_0955_Product_7213.idc:system/usr/idc/Vendor_0955_Product_7213.idc \
  device/nvidia/platform/loki/Vendor_0955_Product_7214.idc:system/usr/idc/Vendor_0955_Product_7214.idc \
  $(LOCAL_PATH)/../../common/dhcpcd.conf:system/etc/dhcpcd/dhcpcd.conf \
  $(LOCAL_PATH)/raydium_ts.idc:system/usr/idc/touch.idc \
  $(LOCAL_PATH)/fts.idc:system/usr/idc/fts.idc \
  $(LOCAL_PATH)/fts.ko:vendor/lib/modules/fts.ko \
  $(LOCAL_PATH)/sensor00fn11.idc:system/usr/idc/sensor00fn11.idc \
  $(LOCAL_PATH)/bt_vendor.conf:system/etc/bluetooth/bt_vendor.conf

ifeq ($(NV_ANDROID_MULTIMEDIA_ENHANCEMENTS),TRUE)
ifeq ($(BOARD_REMOVES_RESTRICTED_CODEC),true)
PRODUCT_COPY_FILES += \
  frameworks/av/media/libstagefright/data/media_codecs_google_audio.xml:system/etc/media_codecs_google_audio.xml \
  frameworks/av/media/libstagefright/data/media_codecs_google_video.xml:system/etc/media_codecs_google_video.xml \
  $(LOCAL_PATH)/media_codecs_no_licence.xml:system/etc/media_codecs.xml \
  $(LOCAL_PATH)/media_codecs_performance.xml:system/etc/media_codecs_performance.xml
else
PRODUCT_COPY_FILES += \
  frameworks/av/media/libstagefright/data/media_codecs_google_audio.xml:system/etc/media_codecs_google_audio.xml \
  frameworks/av/media/libstagefright/data/media_codecs_google_video.xml:system/etc/media_codecs_google_video.xml \
  $(LOCAL_PATH)/media_codecs.xml:system/etc/media_codecs.xml \
  $(LOCAL_PATH)/media_codecs_performance.xml:system/etc/media_codecs_performance.xml
endif
else
PRODUCT_COPY_FILES += \
  frameworks/av/media/libstagefright/data/media_codecs_google_audio.xml:system/etc/media_codecs_google_audio.xml \
  frameworks/av/media/libstagefright/data/media_codecs_google_video.xml:system/etc/media_codecs_google_video.xml \
  $(LOCAL_PATH)/media_codecs_noenhance.xml:system/etc/media_codecs.xml \
  $(LOCAL_PATH)/media_codecs_performance.xml:system/etc/media_codecs_performance.xml
endif

PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/init.e2190.rc:root/init.e2190.rc \
    $(LOCAL_PATH)/init.e2220.rc:root/init.e2220.rc \
    $(LOCAL_PATH)/init.e3350.rc:root/init.e3350.rc \
    $(LOCAL_PATH)/init.jetson_e.rc:root/init.jetson_e.rc \
    $(LOCAL_PATH)/init.abca.rc:root/init.abca.rc \
    $(LOCAL_PATH)/init.abcb.rc:root/init.abcb.rc \
    $(LOCAL_PATH)/init.jetson_cv.rc:root/init.jetson_cv.rc \
    $(LOCAL_PATH)/init.t18x-interposer.rc:root/init.t18x-interposer.rc \
    $(LOCAL_PATH)/init.t210.rc:root/init.t210.rc \
    $(LOCAL_PATH)/init.dualwifi.rc:root/init.dualwifi.rc \
    $(LOCAL_PATH)/init.loki_e_lte.rc:root/init.loki_e_lte.rc \
    $(LOCAL_PATH)/init.loki_e_wifi.rc:root/init.loki_e_wifi.rc \
    $(LOCAL_PATH)/init.loki_e_base.rc:root/init.loki_e_base.rc \
    $(LOCAL_PATH)/init.foster_e.rc:root/init.foster_e.rc \
    $(LOCAL_PATH)/init.foster_e_hdd.rc:root/init.foster_e_hdd.rc \
    $(LOCAL_PATH)/init.loki_e_common.rc:root/init.loki_e_common.rc \
    $(LOCAL_PATH)/init.foster_e_common.rc:root/init.foster_e_common.rc \
    $(LOCAL_PATH)/init.loki_foster_e_common.rc:root/init.loki_foster_e_common.rc \
    $(LOCAL_PATH)/init.darcy.rc:root/init.darcy.rc \
    $(LOCAL_PATH)/init.sif.rc:root/init.sif.rc \
    $(LOCAL_PATH)/init.recovery.darcy.rc:root/init.recovery.sif.rc \
    $(LOCAL_PATH)/init.recovery.darcy.rc:root/init.recovery.darcy.rc \
    $(LOCAL_PATH)/init.recovery.darcy.rc:root/init.recovery.foster_e.rc \
    $(LOCAL_PATH)/init.recovery.foster_e_hdd.rc:root/init.recovery.foster_e_hdd.rc \
    $(LOCAL_PATH)/init.recovery.jetson_cv.rc:root/init.recovery.jetson_cv.rc \
    $(DEVICE_ROOT)/common/init.none.rc:root/init.none.rc \
    $(DEVICE_ROOT)/common/init.tegra_emmc.rc:root/init.tegra_emmc.rc \
    $(DEVICE_ROOT)/common/init.ray_touch.rc:root/init.ray_touch.rc \
    $(DEVICE_ROOT)/common/init.tegra_sata.rc:root/init.tegra_sata.rc \
    $(DEVICE_ROOT)/soc/t210/init.t210_common.rc:root/init.t210_common.rc \
    $(DEVICE_ROOT)/soc/t210/init.t18x-interposer_common.rc:root/init.t18x-interposer_common.rc \
    $(DEVICE_ROOT)/common/init.nvphsd.rc:root/init.nvphsd.rc \
    $(DEVICE_ROOT)/common/init.sata.configs.rc:root/init.sata.configs.rc \
    $(DEVICE_ROOT)/common/badblk.sh:system/bin/badblk.sh \
    $(DEVICE_ROOT)/common/badblocks:system/bin/badblocks \
    $(DEVICE_ROOT)/common/dumpe2fs:system/bin/dumpe2fs \
    $(DEVICE_ROOT)/common/init.tlk.rc:root/init.tlk.rc \
    $(DEVICE_ROOT)/common/init.hdcp.rc:root/init.hdcp.rc

ifeq ($(PLATFORM_IS_AFTER_N),1)
PRODUCT_COPY_FILES += \
    device/nvidia/common/nvphsd_common.conf:$(TARGET_COPY_OUT_ODM)/etc/nvphsd_common.conf \
    device/nvidia/platform/t210/nvphsd.conf:$(TARGET_COPY_OUT_ODM)/etc/nvphsd.conf
else
PRODUCT_COPY_FILES += \
    device/nvidia/common/nvphsd_common.conf:system/etc/nvphsd_common.conf \
    device/nvidia/platform/t210/nvphsd.conf:system/etc/nvphsd.conf
endif

PRODUCT_COPY_FILES += \
    $(DEVICE_ROOT)/common/init.recovery.configfs.usb.rc:root/init.recovery.usb.rc

PRODUCT_COPY_FILES += \
    $(DEVICE_ROOT)/common/init.xusb.configfs.usb.rc:root/init.xusb.configfs.usb.rc

ifeq ($(NV_ANDROID_FRAMEWORK_ENHANCEMENTS), TRUE)
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/../../common/nvphsd_setup.sh:vendor/bin/nvphsd_setup.sh \
    $(DEVICE_ROOT)/common/adbenable.sh:vendor/bin/adbenable.sh \
    $(LOCAL_PATH)/update_js_touch_fw.sh:vendor/bin/update_js_touch_fw.sh
else
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/../../common/nvphsd_setup.sh.old:vendor/bin/nvphsd_setup.sh \
    $(DEVICE_ROOT)/common/adbenable.sh.old:vendor/bin/adbenable.sh \
    $(LOCAL_PATH)/update_js_touch_fw.sh.old:vendor/bin/update_js_touch_fw.sh
endif

ifeq ($(PLATFORM_IS_AFTER_M),)
PRODUCT_COPY_FILES += \
    system/core/rootdir/init.usb.configfs.rc:root/init.usb.configfs.rc
endif

ifeq ($(PLATFORM_IS_AFTER_LOLLIPOP),1)
PRODUCT_COPY_FILES += \
    $(DEVICE_ROOT)/common/init.tegra_m.rc:root/init.tegra.rc \
    $(LOCAL_PATH)/fstab_m.t210ref:root/fstab.e2190 \
    $(LOCAL_PATH)/fstab_m.t210ref:root/fstab.e2220 \
    $(LOCAL_PATH)/fstab_m.t210ref:root/fstab.e3350 \
    $(LOCAL_PATH)/fstab_m.t210ref:root/fstab.jetson_e \
    $(LOCAL_PATH)/fstab_m.t210ref:root/fstab.abca \
    $(LOCAL_PATH)/fstab_m.t210ref:root/fstab.abcb \
    $(LOCAL_PATH)/fstab_m.t210ref:root/fstab.jetson_cv \
    $(LOCAL_PATH)/fstab_m.t210ref:root/fstab.t18x-interposer \
    $(LOCAL_PATH)/fstab_m.loki_e:root/fstab.loki_e_lte \
    $(LOCAL_PATH)/fstab_m.loki_e:root/fstab.loki_e_base \
    $(LOCAL_PATH)/fstab_m.loki_e:root/fstab.loki_e_wifi \
    $(LOCAL_PATH)/fstab_m.foster_e:root/fstab.foster_e \
    $(LOCAL_PATH)/fstab_m.foster_e_hdd:root/fstab.foster_e_hdd \
    $(LOCAL_PATH)/fstab_m.darcy:root/fstab.darcy \
    $(LOCAL_PATH)/fstab_m_usb.darcy:root/fstabusb.darcy \
    $(LOCAL_PATH)/fstab.sif:root/fstab.sif
ifneq ($(filter user%,$(TARGET_BUILD_VARIANT)),)
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/fstab_m.t210ref_encrypt:root/fstab.jetson_e \
    $(LOCAL_PATH)/fstab_m.t210ref_encrypt:root/fstab.jetson_cv
else
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/fstab_m.t210ref:root/fstab.jetson_e \
    $(LOCAL_PATH)/fstab_m.t210ref:root/fstab.jetson_cv
endif
else
PRODUCT_COPY_FILES += \
    $(DEVICE_ROOT)/common/init.tegra.rc:root/init.tegra.rc \
    $(LOCAL_PATH)/fstab.t210ref:root/fstab.e2190 \
    $(LOCAL_PATH)/fstab.t210ref:root/fstab.e2220 \
    $(LOCAL_PATH)/fstab.t210ref:root/fstab.e3350 \
    $(LOCAL_PATH)/fstab.t210ref:root/fstab.jetson_e \
    $(LOCAL_PATH)/fstab.t210ref:root/fstab.abca \
    $(LOCAL_PATH)/fstab.t210ref:root/fstab.abcb \
    $(LOCAL_PATH)/fstab.t210ref:root/fstab.jetson_cv \
    $(LOCAL_PATH)/fstab.t210ref:root/fstab.t18x-interposer \
    $(LOCAL_PATH)/fstab.loki_e:root/fstab.loki_e_lte \
    $(LOCAL_PATH)/fstab.loki_e:root/fstab.loki_e_base \
    $(LOCAL_PATH)/fstab.loki_e:root/fstab.loki_e_wifi \
    $(LOCAL_PATH)/fstab.foster_e:root/fstab.foster_e \
    $(LOCAL_PATH)/fstab.foster_e_hdd:root/fstab.foster_e_hdd
endif

DEVICE_ROOT :=

# System power mode configuration file
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/power.loki_e_common.rc:$(TARGET_COPY_OUT_ODM)/etc/power.loki_e_lte.rc \
    $(LOCAL_PATH)/power.loki_e_common.rc:$(TARGET_COPY_OUT_ODM)/etc/power.loki_e_wifi.rc \
    $(LOCAL_PATH)/power.loki_e_common.rc:$(TARGET_COPY_OUT_ODM)/etc/power.loki_e_base.rc \
    $(LOCAL_PATH)/power.foster_e_common.rc:$(TARGET_COPY_OUT_ODM)/etc/power.foster_e.rc \
    $(LOCAL_PATH)/power.foster_e_common.rc:$(TARGET_COPY_OUT_ODM)/etc/power.foster_e_hdd.rc \
    $(LOCAL_PATH)/power.darcy.rc:$(TARGET_COPY_OUT_ODM)/etc/power.darcy.rc \
    $(LOCAL_PATH)/power.jetson_e.rc:$(TARGET_COPY_OUT_ODM)/etc/power.jetson_e.rc \
    $(LOCAL_PATH)/power.abca.rc:$(TARGET_COPY_OUT_ODM)/etc/power.abca.rc \
    $(LOCAL_PATH)/power.abca.rc:$(TARGET_COPY_OUT_ODM)/etc/power.abcb.rc \
    $(LOCAL_PATH)/power.jetson_e.rc:$(TARGET_COPY_OUT_ODM)/etc/power.jetson_cv.rc \
    $(LOCAL_PATH)/power.jetson_e.rc:$(TARGET_COPY_OUT_ODM)/etc/power.jetson_cv_k49.rc \
    $(LOCAL_PATH)/power.jetson_e.rc:$(TARGET_COPY_OUT_ODM)/etc/power.t18x-interposer.rc

# System thermalhal configuration file
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/thermalhal.jetson_e.xml:system/etc/thermalhal.jetson_cv.xml

# Face detection model
PRODUCT_COPY_FILES += \
    vendor/nvidia/tegra/core/include/ft/model_frontalface.xml:system/etc/model_frontal.xml

PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/../../common/cluster:system/bin/cluster \
    $(LOCAL_PATH)/../../common/cluster_get.sh:system/bin/cluster_get.sh \
    $(LOCAL_PATH)/../../common/cluster_set.sh:system/bin/cluster_set.sh \
    $(LOCAL_PATH)/../../common/dcc:system/bin/dcc \
    $(LOCAL_PATH)/../../common/hotplug:system/bin/hotplug \
    $(LOCAL_PATH)/../../common/mount_debugfs.sh:system/bin/mount_debugfs.sh

PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/enctune.conf:system/etc/enctune.conf

ifeq ($(wildcard vendor/nvidia/tegra/core-private),vendor/nvidia/tegra/core-private)
    BCMBINARIES_PATH := vendor/nvidia/tegra/3rdparty/bcmbinaries
    CYWBINARIES_PATH := vendor/nvidia/tegra/3rdparty/cypress
else
    BCMBINARIES_PATH := vendor/nvidia/tegra/prebuilt/t210/3rdparty/bcmbinaries
    CYWBINARIES_PATH := vendor/nvidia/tegra/prebuilt/t210/3rdparty/cypress
endif

#Product-specific wifi firmware/nvram files
ifeq ($(findstring loki_e, $(TARGET_PRODUCT)), loki_e)
    PRODUCT_COPY_FILES += \
        $(BCMBINARIES_PATH)/bcm4354a1/wlan/atv/nvram_loki_e_4354.txt:$(TARGET_COPY_OUT_VENDOR)/firmware/nvram_loki_e_4354.txt \
        $(BCMBINARIES_PATH)/bcm4354a1/wlan/atv/nvram_loki_e_antenna_tuned_4354.txt:$(TARGET_COPY_OUT_VENDOR)/firmware/nvram_loki_e_antenna_tuned_4354.txt \
        $(call add-to-product-copy-files-if-exists, vendor/nvidia/internal/t210/3rdparty/bcmbinaries/bcm4354a1/wlan/sdio-ag-p2p-pno-aoe-pktfilter-keepalive-sr-mchan-proptxstatus-ampduhostreorder-lpc-wl11u-txbf-pktctx-okc-tdls-ccx-ve-mfp-ltecxgpio.bin:$(TARGET_COPY_OUT_VENDOR)/firmware/fw_bcmdhd.bin)
else ifeq ($(findstring foster_e, $(TARGET_PRODUCT)), foster_e)
    PRODUCT_COPY_FILES += \
        $(BCMBINARIES_PATH)/bcm4354a1/wlan/atv/nvram_foster_e_4354.txt:$(TARGET_COPY_OUT_VENDOR)/firmware/nvram_foster_e_4354.txt \
        $(BCMBINARIES_PATH)/bcm4354a1/wlan/atv/nvram_foster_e_antenna_tuned_4354.txt:$(TARGET_COPY_OUT_VENDOR)/firmware/nvram_foster_e_antenna_tuned_4354.txt \
        $(CYWBINARIES_PATH)/bcm4354a1/wlan/atv/sdio-ag-p2p-pno-aoe-pktfilter-keepalive-sr-mchan-pktctx-proptxstatus-ampduhostreorder-lpc-pwropt-txbf-wl11u-mfp-tdls-ltecx-wfds-mchandump-atv.bin:$(TARGET_COPY_OUT_VENDOR)/firmware/fw_bcmdhd.bin \
        $(CYWBINARIES_PATH)/bcm4354a1/wlan/atv/foster.clm_blob:$(TARGET_COPY_OUT_VENDOR)/firmware/bcmdhd_clm_foster.blob
else ifneq ($(filter darcy% mdarcy% t210ref, $(TARGET_PRODUCT)),)
#Copy Foster NVRAM files for Darcy builds
    PRODUCT_COPY_FILES += \
        $(BCMBINARIES_PATH)/bcm4354a1/wlan/atv/nvram_foster_e_4354.txt:$(TARGET_COPY_OUT_VENDOR)/firmware/nvram_foster_e_4354.txt \
        $(BCMBINARIES_PATH)/bcm4354a1/wlan/atv/nvram_foster_e_antenna_tuned_4354.txt:$(TARGET_COPY_OUT_VENDOR)/firmware/nvram_foster_e_antenna_tuned_4354.txt \
        $(BCMBINARIES_PATH)/bcm4354a1/wlan/atv/nvram_darcy_a00.txt:$(TARGET_COPY_OUT_VENDOR)/firmware/nvram_darcy_a00.txt \
        $(CYWBINARIES_PATH)/bcm4354a1/wlan/atv/sdio-ag-p2p-pno-aoe-pktfilter-keepalive-sr-mchan-pktctx-proptxstatus-ampduhostreorder-lpc-pwropt-txbf-wl11u-mfp-tdls-ltecx-wfds-mchandump-atv.bin:$(TARGET_COPY_OUT_VENDOR)/firmware/fw_bcmdhd.bin \
        $(CYWBINARIES_PATH)/bcm4354a1/wlan/atv/darcy.clm_blob:$(TARGET_COPY_OUT_VENDOR)/firmware/bcmdhd_clm_darcy.blob \
        $(CYWBINARIES_PATH)/bcm4354a1/wlan/atv/foster.clm_blob:$(TARGET_COPY_OUT_VENDOR)/firmware/bcmdhd_clm_foster.blob \
        $(CYWBINARIES_PATH)/bcm4354a1/wlan/atv/flynn-hp.clm_blob:$(TARGET_COPY_OUT_VENDOR)/firmware/bcmdhd_clm_darcy_flynn-hp.blob \
        $(CYWBINARIES_PATH)/bcm4356a3/wlan/fw_4356a3_prod.bin:$(TARGET_COPY_OUT_VENDOR)/firmware/fw_bcmdhd_4356.bin \
        $(CYWBINARIES_PATH)/bcm4356a3/wlan/fw_4356a3_prod.clm_blob:/system/etc/wifi/bcmdhd_clm_sif.blob \
        $(CYWBINARIES_PATH)/bcm4356a3/bluetooth/BCM4356A3.hcd:$(TARGET_COPY_OUT_VENDOR)/firmware/bcm4356a3.hcd \
        $(CYWBINARIES_PATH)/bcm4356a3/wlan/brcmfmac4356-pcie.bin:$(TARGET_COPY_OUT_VENDOR)/firmware/brcmfmac4356-pcie.bin \
        $(CYWBINARIES_PATH)/bcm4356a3/wlan/brcmfmac4356-pcie.clm_blob:$(TARGET_COPY_OUT_VENDOR)/firmware/brcmfmac4356-pcie.clm_blob \
        $(CYWBINARIES_PATH)/bcm4356a3/wlan/brcmfmac4356-pcie.txt:$(TARGET_COPY_OUT_VENDOR)/firmware/brcmfmac4356-pcie.txt
else ifeq ($(findstring t210ref, $(TARGET_PRODUCT)), t210ref)
    #copy T210 ERS files as well if repo exists
    PRODUCT_COPY_FILES += \
        $(BCMBINARIES_PATH)/bcm4354a1/wlan/emb/nvram_jetsonE_cv_4354.txt:$(TARGET_COPY_OUT_VENDOR)/firmware/nvram_jetsonE_cv_4354.txt \
        $(call add-to-product-copy-files-if-exists, vendor/nvidia/internal/t210/3rdparty/bcmbinaries/bcm4354a1/wlan/sdio-ag-p2p-pno-aoe-pktfilter-keepalive-sr-mchan-proptxstatus-ampduhostreorder-lpc-wl11u-txbf-pktctx-okc-tdls-ccx-ve-mfp-ltecxgpio.bin:$(TARGET_COPY_OUT_VENDOR)/firmware/bcm4354/fw_bcmdhd.bin) \
        $(call add-to-product-copy-files-if-exists, vendor/nvidia/internal/t210/3rdparty/bcmbinaries/bcm4354a1/wlan/nvram_4354.txt:$(TARGET_COPY_OUT_VENDOR)/firmware/nvram_4354.txt)
    ifeq ($(wildcard vendor/nvidia/tegra/core-private),vendor/nvidia/tegra/core-private)
        PRODUCT_COPY_FILES += $(CYWBINARIES_PATH)/bcm4354a1/wlan/emb/sdio-ag-p2p-pno-aoe-pktfilter-keepalive-sr-mchan-pktctx-proptxstatus-ampduhostreorder-lpc-pwropt-txbf-wl11u-mfp-tdls-ltecx-wfds-mchandump-emb.bin:$(TARGET_COPY_OUT_VENDOR)/firmware/fw_bcmdhd.bin
    else
        PRODUCT_COPY_FILES += $(CYWBINARIES_PATH)/bcm4354a1/wlan/emb/sdio-ag-p2p-pno-aoe-pktfilter-keepalive-sr-mchan-pktctx-proptxstatus-ampduhostreorder-lpc-pwropt-txbf-wl11u-mfp-tdls-ltecx-wfds-mchandump-emb.bin:$(TARGET_COPY_OUT_VENDOR)/firmware/fw_bcmdhd.bin
    endif
    ## eks2 data blob
    ifeq ($(TARGET_BUILD_TYPE),debug)
      PRODUCT_COPY_FILES += \
        $(call add-to-product-copy-files-if-exists, vendor/nvidia/tegra/ote/nveks2/data/eks2_private.dat:vendor/app/eks2/eks2.dat)
    else
      PRODUCT_COPY_FILES += \
        $(call add-to-product-copy-files-if-exists, $(LOCAL_PATH)/eks2/eks2_public.dat:vendor/app/eks2/eks2.dat)
    endif # ifeq($(TARGET_BUILD_TYPE, debug))
else
    PRODUCT_COPY_FILES += \
        $(call add-to-product-copy-files-if-exists, vendor/nvidia/internal/t210/3rdparty/bcmbinaries/bcm4354a1/wlan/sdio-ag-p2p-pno-aoe-pktfilter-keepalive-sr-mchan-proptxstatus-ampduhostreorder-lpc-wl11u-txbf-pktctx-okc-tdls-ccx-ve-mfp-ltecxgpio.bin:$(TARGET_COPY_OUT_VENDOR)/firmware/bcm4354/fw_bcmdhd.bin) \
        $(call add-to-product-copy-files-if-exists, vendor/nvidia/internal/t210/3rdparty/bcmbinaries/bcm4354a1/wlan/nvram_4354.txt:$(TARGET_COPY_OUT_VENDOR)/firmware/nvram_4354.txt)
endif

#BT Firmware file for BCM4354
PRODUCT_COPY_FILES += $(CYWBINARIES_PATH)/bcm4354a1/bluetooth/BCM4350C0.hcd:$(TARGET_COPY_OUT_VENDOR)/firmware/bcm4350.hcd

BCMBINARIES_PATH :=

# Nvidia Miracast
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/../../common/miracast/com.nvidia.miracast.xml:system/etc/permissions/com.nvidia.miracast.xml

ifneq ($(filter darcy% foster% mdarcy% sif%,$(TARGET_PRODUCT)),)
PRODUCT_COPY_FILES += $(call add-to-product-copy-files-if-exists, vendor/nvidia/tegra/tnspec_data/t210/tnspec_foster.json:tnspec_foster.json)
endif
PRODUCT_COPY_FILES += $(call add-to-product-copy-files-if-exists, vendor/nvidia/tegra/tnspec_data/t210/tnspec.json:tnspec.json)

#Hauppauge DualHD Tuner firmware
PRODUCT_COPY_FILES += \
    $(call add-to-product-copy-files-if-exists, $(LOCAL_PATH)/../../common/usbtuner/firmware/dvb-demod-si2168-b40-01.fw:$(TARGET_COPY_OUT_VENDOR)/firmware/dvb-demod-si2168-b40-01.fw)

# seccomp policy files
ifeq ($(PLATFORM_IS_AFTER_N),1)
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/seccomp/mediaextractor-seccomp.policy:$(TARGET_COPY_OUT_VENDOR)/etc/seccomp_policy/mediaextractor.policy \
    $(LOCAL_PATH)/seccomp/mediacodec-seccomp.policy:$(TARGET_COPY_OUT_VENDOR)/etc/seccomp_policy/mediacodec.policy
endif

# OTA version definition.  Depends on environment variable NV_OTA_VERSION
# being set prior to building.
ifneq ($(NV_OTA_VERSION),)
    PRODUCT_PROPERTY_OVERRIDES += \
        ro.build.version.ota = $(NV_OTA_VERSION)
endif
