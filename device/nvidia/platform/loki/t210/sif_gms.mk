# NVIDIA Tegra 210b01 "sif" development system
#
# Copyright (c) 2018, NVIDIA Corporation.  All rights reserved.

_GOOGLE_GTVS_APP_PATH := 3rdparty/google/gtvs-apps/tv/64

PRODUCT_PACKAGES := \
    AndroidMediaShell \
    AtvRemoteService \
    Backdrop \
    BugReportSender \
    GooglePackageInstaller \
    FrameworkPackageStubs \
    GoogleBackupTransport \
    GoogleCalendarSyncAdapter \
    GoogleContactsSyncAdapter \
    GoogleFeedback \
    GoogleOneTimeInitializer \
    GooglePartnerSetup \
    GoogleServicesFramework \
    Katniss \
    LeanbackIme \
    LeanbackLauncher \
    Music2Pano \
    NoTouchAuthDelegate \
    PrebuiltGmsCorePano \
    PlayGamesPano \
    RecommendationsService \
    SecondScreenSetup \
    SecondScreenSetupAuthBridge \
    SetupWraith \
    talkback \
    Tubesky \
    TVLauncher \
    TVRecommendations \
    TvTutorials \
    VideosPano \
    WebViewGoogle \
    YouTubeLeanback \
    GoogleExtServices \
    GoogleExtShared \


# Configuration files for GMS apps
PRODUCT_COPY_FILES := \
    $(_GOOGLE_GTVS_APP_PATH)/etc/sysconfig/google.xml:system/etc/sysconfig/google.xml \
    $(_GOOGLE_GTVS_APP_PATH)/etc/permissions/privapp-permissions-google.xml:system/etc/permissions/privapp-permissions-google.xml \
    $(_GOOGLE_GTVS_APP_PATH)/etc/permissions/privapp-permissions-atv.xml:system/etc/permissions/privapp-permissions-atv.xml \
    $(_GOOGLE_GTVS_APP_PATH)/etc/sysconfig/google_atv.xml:system/etc/sysconfig/google_atv.xml

# Add gms_tv specific overlay
PRODUCT_PACKAGE_OVERLAYS += $(_GOOGLE_GTVS_APP_PATH)/products/gms_tv_overlay

# Overlay for GMS devices
$(call inherit-product, device/sample/products/backup_overlay.mk)
$(call inherit-product, device/sample/products/location_overlay.mk)
PRODUCT_PACKAGE_OVERLAYS += $(_GOOGLE_GTVS_APP_PATH)/products/gms_overlay

# Overrides
PRODUCT_PROPERTY_OVERRIDES += \
    ro.setupwizard.mode=OPTIONAL \
    ro.com.google.gmsversion=O_release
