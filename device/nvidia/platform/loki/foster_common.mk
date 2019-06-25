# NVIDIA Tegra4 "foster" development system
#
# Copyright (c) 2013-2018 NVIDIA Corporation.  All rights reserved.
#

PRODUCT_LOCALES := en_US in_ID ca_ES cs_CZ da_DK de_DE en_GB es_ES es_US tl_PH fr_FR hr_HR it_IT lv_LV lt_LT hu_HU nl_NL nb_NO pl_PL pt_BR pt_PT ro_RO sk_SK sl_SI fi_FI sv_SE vi_VN tr_TR el_GR bg_BG ru_RU sr_RS uk_UA iw_IL ar_EG fa_IR th_TH ko_KR zh_CN zh_TW ja_JP en_AU en_CA en_NZ fr_CA

PRODUCT_PROPERTY_OVERRIDES += ro.radio.noril=true

PRODUCT_PACKAGE_OVERLAYS += $(LOCAL_PATH)/overlays/$(PLATFORM_VERSION_LETTER_CODE)/wifi

DEVICE_PACKAGE_OVERLAYS := $(LOCAL_PATH)/overlays/$(PLATFORM_VERSION_LETTER_CODE)/common

PRODUCT_PROPERTY_OVERRIDES += \
    ro.sf.lcd_density=320

# Additional AOSP packages not included in Android TV
PRODUCT_PACKAGES += \
    DocumentsUI \
    cyload \
    CaptivePortalLogin

PRODUCT_COPY_FILES += \
  $(LOCAL_PATH)/Vendor_0955_Product_7205.kl:system/usr/keylayout/Vendor_0955_Product_7205.kl \
  $(LOCAL_PATH)/Vendor_0955_Product_7212.kl:system/usr/keylayout/Vendor_0955_Product_7212.kl \
  $(LOCAL_PATH)/Vendor_0955_Product_7213.kl:system/usr/keylayout/Vendor_0955_Product_7213.kl \
  $(LOCAL_PATH)/Vendor_1b1c_Product_0a38.kl:system/usr/keylayout/Vendor_1b1c_Product_0a38.kl \
  $(LOCAL_PATH)/Vendor_1b1c_Product_0a38.kl:system/usr/keylayout/Vendor_1b1c_Product_0a2b.kl \
  $(LOCAL_PATH)/Vendor_1b1c_Product_0a38.kl:system/usr/keylayout/Vendor_1b1c_Product_1b2a.kl \
  $(LOCAL_PATH)/Vendor_1b1c_Product_0a38.kl:system/usr/keylayout/Vendor_1b1c_Product_1b29.kl \
  $(LOCAL_PATH)/Vendor_1b1c_Product_0a38.kl:system/usr/keylayout/Vendor_1b1c_Product_1b27.kl \
  $(LOCAL_PATH)/Vendor_1b1c_Product_0a38.kl:system/usr/keylayout/Vendor_1b1c_Product_1b25.kl \
  $(LOCAL_PATH)/Vendor_1b1c_Product_0a38.kl:system/usr/keylayout/Vendor_1b1c_Product_1b23.kl \
  $(LOCAL_PATH)/Vendor_1b1c_Product_0a38.kl:system/usr/keylayout/Vendor_1b1c_Product_0a1d.kl \
  $(LOCAL_PATH)/Vendor_1b1c_Product_0a38.kl:system/usr/keylayout/Vendor_1b1c_Product_0a1c.kl \
  $(LOCAL_PATH)/Vendor_1b1c_Product_0a38.kl:system/usr/keylayout/Vendor_1b1c_Product_0a1a.kl \
  $(LOCAL_PATH)/Vendor_1b1c_Product_0a38.kl:system/usr/keylayout/Vendor_1b1c_Product_0a17.kl \
  $(LOCAL_PATH)/Vendor_1b1c_Product_0a38.kl:system/usr/keylayout/Vendor_1b1c_Product_0a16.kl \
  $(LOCAL_PATH)/Vendor_1b1c_Product_0a38.kl:system/usr/keylayout/Vendor_1b1c_Product_0a14.kl \
  $(LOCAL_PATH)/gpio-keys.kl:system/usr/keylayout/gpio-keys.kl \
  device/nvidia/common/nvphsd_common.conf:system/etc/nvphsd_common.conf \
  device/nvidia/platform/t210/nvphsd.foster.conf:system/etc/nvphsd.conf \
  $(call add-to-product-copy-files-if-exists, vendor/nvidia/loki/utils/cyload/cyupdate.sh:$(TARGET_COPY_OUT_VENDOR)/bin/cyupdate.sh)

PRODUCT_AAPT_CONFIG += xlarge large

