# NVIDIA Tegra development system
#
# Copyright (c) 2017-2018 NVIDIA Corporation.  All rights reserved.

ifndef SENSORS_LOKI_E_TAG
SENSORS_LOKI_E_TAG := 1

SENSOR_BOARD_VERSION            := e2530
SENSOR_BUILD_VERSION            := loki_e
SENSOR_BUILD_CFLAGS             :=
SENSOR_FUSION_VENDOR            := Invensense
SENSOR_FUSION_VERSION           := mpl530
SENSOR_FUSION_API               := nvs
SENSOR_FUSION_CFLAGS            :=
SENSOR_FUSION_LIBRARIES         :=
SENSOR_HAL_VERSION              := nvs
SENSOR_HAL_API                  := 1.4
SENSOR_HAL_CFLAGS               := -DENABLE_TRACE -DUSE_PTRACE
SENSOR_HAL_LIBRARIES            := libcutils
SENSOR_HAL_OS_INTERFACE_SRC     := NvsAos.cpp
SENSOR_HAL_LOCAL_DRIVER_SRC     := NvsNullDriver.cpp
SENSOR_REQUIRED_MODULES         :=
SENSOR_SHARED_LIBRARIES         :=
SENSOR_PRODUCT_TAG              := $(SENSOR_BUILD_VERSION).$(SENSOR_BOARD_VERSION)

PRODUCT_PACKAGES                += sensor-grinder sg-stress.py

# set unified sensor variables
$(eval $(call _run_convert_tag_sensor_cfg,$(SENSOR_PRODUCT_TAG)))
endif
