# Copyright (C) 2014 The Android Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


LOCAL_PATH := $(call my-dir)

ifeq ($(TARGET_TEGRA_VERSION), t210)
# HAL module implemenation stored in
# hw/<POWERS_HARDWARE_MODULE_ID>.<ro.hardware>.so
include $(NVIDIA_DEFAULTS)

LOCAL_C_INCLUDES += device/nvidia/common/power
LOCAL_MODULE_RELATIVE_PATH := hw
LOCAL_SHARED_LIBRARIES := liblog libcutils libutils libdl libnvos libexpat
ifeq ($(PLATFORM_IS_AFTER_N), 1)
    LOCAL_SHARED_LIBRARIES += libnvphs
endif
LOCAL_STATIC_LIBRARIES := libpowerhal
LOCAL_SRC_FILES := power.cpp

# Loki-e / foster-e skus
LOCAL_MODULE := power.tegra
ifeq ($(TARGET_PRODUCT),loki_e)
LOCAL_MODULE := power.loki_e
endif

ifeq ($(TARGET_PRODUCT),loki_e_lte)
LOCAL_MODULE := power.loki_e_lte
endif

ifeq ($(TARGET_PRODUCT),loki_e_wifi)
LOCAL_MODULE := power.loki_e_wifi
endif

ifeq ($(TARGET_PRODUCT),foster_e)
LOCAL_MODULE := power.foster_e
endif

ifeq ($(TARGET_PRODUCT),$(filter $(TARGET_PRODUCT),darcy darcy_ironfist mdarcy))
LOCAL_MODULE := power.darcy
endif

ifeq ($(TARGET_PRODUCT),sif)
LOCAL_MODULE := power.sif
endif

include $(NVIDIA_SHARED_LIBRARY)

#
# Build for Foster_e_hdd sku
#
include $(NVIDIA_DEFAULTS)

LOCAL_C_INCLUDES += device/nvidia/common/power
LOCAL_C_INCLUDES += device/nvidia/drivers/sata
LOCAL_MODULE_RELATIVE_PATH := hw
LOCAL_SHARED_LIBRARIES := liblog libcutils libutils libdl libnvos libtegra_sata_hal libexpat
ifeq ($(PLATFORM_IS_AFTER_N), 1)
    LOCAL_SHARED_LIBRARIES += libnvphs
endif
LOCAL_STATIC_LIBRARIES := libpowerhal
LOCAL_SRC_FILES := power.cpp

LOCAL_CFLAGS += -DENABLE_SATA_STANDBY_MODE
LOCAL_MODULE := power.foster_e_hdd

include $(NVIDIA_SHARED_LIBRARY)
endif
