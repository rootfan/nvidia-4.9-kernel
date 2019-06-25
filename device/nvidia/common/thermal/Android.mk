# Copyright (C) 2016 The Android Open Source Project
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

ifneq ($(TARGET_SIMULATOR),true)
include $(NVIDIA_DEFAULTS)

LOCAL_MODULE := thermal.tegra
LOCAL_MODULE_RELATIVE_PATH := hw

LOCAL_SHARED_LIBRARIES := liblog \
	libcutils \
	libxml2

LOCAL_SRC_FILES += thermal.c parse_thermal.c
LOCAL_CFLAGS := -Wno-unused-parameter


LOCAL_C_INCLUDES += \
	external/icu/icu4c/source/common \
	external/libxml2/include

include $(NVIDIA_SHARED_LIBRARY)
endif # !TARGET_SIMULATOR
