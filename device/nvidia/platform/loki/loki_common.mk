# NVIDIA Tegra4 "loki" development system
#
# Copyright (c) 2013-2018 NVIDIA Corporation.  All rights reserved.
#

## These are default init.rc and settings files for all Loki skus

PRODUCT_LOCALES := en_US in_ID ca_ES cs_CZ da_DK de_DE en_GB es_ES es_US tl_PH fr_FR hr_HR it_IT lv_LV lt_LT hu_HU nl_NL nb_NO pl_PL pt_BR pt_PT ro_RO sk_SK sl_SI fi_FI sv_SE vi_VN tr_TR el_GR bg_BG ru_RU sr_RS uk_UA iw_IL ar_EG fa_IR th_TH ko_KR zh_CN zh_TW ja_JP

PRODUCT_COPY_FILES += \
    frameworks/native/data/etc/android.hardware.sensor.light.xml:system/etc/permissions/android.hardware.sensor.light.xml \

PRODUCT_PACKAGE_OVERLAYS += $(LOCAL_PATH)/overlays/$(PLATFORM_VERSION_LETTER_CODE)/loki

DEVICE_PACKAGE_OVERLAYS := $(LOCAL_PATH)/overlays/$(PLATFORM_VERSION_LETTER_CODE)/common

# Additional AOSP packages not included in Android TV
PRODUCT_PACKAGES += \
    DocumentsUI \
    CaptivePortalLogin

PRODUCT_PROPERTY_OVERRIDES += \
    ro.sf.lcd_density=320

PRODUCT_COPY_FILES += \
  $(LOCAL_PATH)/Vendor_0955_Product_7205.kl:system/usr/keylayout/Vendor_0955_Product_7205.kl \
  $(LOCAL_PATH)/Vendor_0955_Product_7210.kl:system/usr/keylayout/Vendor_0955_Product_7210.kl \
  $(LOCAL_PATH)/gpio-keys.kl:system/usr/keylayout/gpio-keys.kl \
  device/nvidia/common/nvphsd_common.conf:system/etc/nvphsd_common.conf \
  device/nvidia/platform/t210/nvphsd.conf:system/etc/nvphsd.conf

PRODUCT_AAPT_CONFIG += xlarge large

