# NVIDIA Tegra7 "ERS" development system
#
# Copyright (c) 2014-2016, NVIDIA Corporation.  All rights reserved.

## This is the file that is common for all ERS skus.

PRODUCT_PACKAGES += \
        nfc.tegra \
        SoundRecorder

PRODUCT_COPY_FILES += \
    frameworks/native/data/etc/tablet_core_hardware.xml:system/etc/permissions/tablet_core_hardware.xml \
    frameworks/native/data/etc/android.hardware.touchscreen.multitouch.jazzhand.xml:system/etc/permissions/android.hardware.touchscreen.multitouch.jazzhand.xml \
    frameworks/native/data/etc/android.hardware.camera.xml:system/etc/permissions/android.hardware.camera.xml \
    frameworks/native/data/etc/android.hardware.camera.autofocus.xml:system/etc/permissions/android.hardware.camera.autofocus.xml \
    frameworks/native/data/etc/android.hardware.camera.front.xml:system/etc/permissions/android.hardware.camera.front.xml \
    frameworks/native/data/etc/android.hardware.camera.full.xml:system/etc/permissions/android.hardware.camera.full.xml \
    frameworks/native/data/etc/android.hardware.camera.raw.xml:system/etc/permissions/android.hardware.camera.raw.xml \
    frameworks/native/data/etc/android.hardware.sensor.accelerometer.xml:system/etc/permissions/android.hardware.sensor.accelerometer.xml \
    frameworks/native/data/etc/android.hardware.sensor.compass.xml:system/etc/permissions/android.hardware.sensor.compass.xml \
    frameworks/native/data/etc/android.hardware.sensor.gyroscope.xml:system/etc/permissions/android.hardware.sensor.gyroscope.xml \
    frameworks/native/data/etc/android.hardware.sensor.barometer.xml:system/etc/permissions/android.hardware.sensor.barometer.xml \
    frameworks/native/data/etc/android.hardware.sensor.ambient_temperature.xml:system/etc/permissions/android.hardware.sensor.ambient_temperature.xml \
    frameworks/native/data/etc/android.hardware.sensor.light.xml:system/etc/permissions/android.hardware.sensor.light.xml \
    frameworks/native/data/etc/handheld_core_hardware.xml:system/etc/permissions/handheld_core_hardware.xml \
    $(LOCAL_PATH)/nvcamera.conf:system/etc/nvcamera.conf

ifeq ($(NV_ANDROID_MULTIMEDIA_ENHANCEMENTS),TRUE)
PRODUCT_COPY_FILES += \
  $(LOCAL_PATH)/media_profiles.xml:system/etc/media_profiles.xml \
  $(LOCAL_PATH)/abca_media_profiles.xml:system/etc/abca_media_profiles.xml \
  $(LOCAL_PATH)/abca_media_profiles.xml:system/etc/abcb_media_profiles.xml \
  $(LOCAL_PATH)/audio_policy.conf:system/etc/audio_policy.conf
else
PRODUCT_COPY_FILES += \
  $(LOCAL_PATH)/media_profiles_noenhance.xml:system/etc/media_profiles.xml \
  $(LOCAL_PATH)/audio_policy_noenhance.conf:system/etc/audio_policy.conf
endif

PRODUCT_COPY_FILES += \
    device/nvidia/platform/t210/nvaudio_conf.xml:system/etc/nvaudio_conf.xml \
    device/nvidia/platform/t210/abca_nvaudio_conf.xml:system/etc/abca_nvaudio_conf.xml \
    device/nvidia/platform/t210/abca_nvaudio_conf.xml:system/etc/abcb_nvaudio_conf.xml
