# Copyright (C) 2012 The Android Open Source Project
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

ifneq ($(filter t186 t210,$(TARGET_TEGRA_VERSION)), $(TARGET_TEGRA_VERSION))

# HAL module implemenation stored in
# hw/<POWERS_HARDWARE_MODULE_ID>.<ro.hardware>.so
include $(NVIDIA_DEFAULTS)

LOCAL_C_INCLUDES += device/nvidia/common/power
LOCAL_MODULE_RELATIVE_PATH := hw
LOCAL_SHARED_LIBRARIES := liblog libcutils libutils libdl libnvos libexpat
LOCAL_STATIC_LIBRARIES := libpowerhal
LOCAL_SRC_FILES := power.cpp
LOCAL_MODULE := power.$(TARGET_BOARD_PLATFORM)

include $(NVIDIA_SHARED_LIBRARY)
endif
