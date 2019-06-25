# NVIDIA Tegra "T186" development system
#
# Copyright (c) 2014-2018 NVIDIA Corporation.  All rights reserved.

define _get_val
$(strip \
$(subst $(1),,$(filter %$(1),$(2))) \
)
endef

define _add_tag_val
$(strip \
$(if $(1),$(addsuffix $(2),$(1)),) \
)
endef

define _set_sensor_val
$(eval SENSOR_TAG := $(1))
$(eval SENSOR_BOARD_VERSION        := $(call _get_val,$(1),$(SENSOR_BOARD_VERSION_TAG)))
$(eval SENSOR_BUILD_VERSION        := $(call _get_val,$(1),$(SENSOR_BUILD_VERSION_TAG)))
$(eval SENSOR_BUILD_CFLAGS         := $(call _get_val,$(1),$(SENSOR_BUILD_CFLAGS)))
$(eval SENSOR_FUSION_VENDOR        := $(call _get_val,$(1),$(SENSOR_FUSION_VENDOR_TAG)))
$(eval SENSOR_FUSION_VERSION       := $(call _get_val,$(1),$(SENSOR_FUSION_VERSION_TAG)))
$(eval SENSOR_FUSION_API           := $(call _get_val,$(1),$(SENSOR_FUSION_API_TAG)))
$(eval SENSOR_FUSION_CFLAGS        := $(call _get_val,$(1),$(SENSOR_FUSION_CFLAGS_TAG)))
$(eval SENSOR_FUSION_LIBRARIES     := $(call _get_val,$(1),$(SENSOR_FUSION_LIBRARIES_TAG)))
$(eval SENSOR_HAL_VERSION          := $(call _get_val,$(1),$(SENSOR_HAL_VERSION_TAG)))
$(eval SENSOR_HAL_API              := $(call _get_val,$(1),$(SENSOR_HAL_API_TAG)))
$(eval SENSOR_HAL_CFLAGS           := $(call _get_val,$(1),$(SENSOR_HAL_CFLAGS_TAG)))
$(eval SENSOR_HAL_LIBRARIES        := $(call _get_val,$(1),$(SENSOR_HAL_LIBRARIES_TAG)))
$(eval SENSOR_HAL_OS_INTERFACE_SRC := $(call _get_val,$(1),$(SENSOR_HAL_OS_INTERFACE_SRC_TAG)))
$(eval SENSOR_HAL_LOCAL_DRIVER_SRC := $(call _get_val,$(1),$(SENSOR_HAL_LOCAL_DRIVER_SRC_TAG)))
$(eval SENSOR_REQUIRED_MODULES     := $(call _get_val,$(1),$(SENSOR_REQUIRED_MODULES_TAG)))
$(eval SENSOR_SHARED_LIBRARIES     := $(call _get_val,$(1),$(SENSOR_SHARED_LIBRARIES_TAG)))
endef

define _run_sensor_cfg
$(eval $(call _set_sensor_val,$(1)))
$(eval PRODUCT_PROPERTY_OVERRIDES := $(PRODUCT_PROPERTY_OVERRIDES) ro.hardware.sensors.$(SENSOR_BOARD_VERSION)=$(SENSOR_BUILD_VERSION).$(SENSOR_BOARD_VERSION).api_v$(SENSOR_HAL_API).$(SENSOR_FUSION_VERSION).$(SENSOR_FUSION_API))
$(eval PRODUCT_PACKAGES := $(PRODUCT_PACKAGES) sensors.$(SENSOR_BUILD_VERSION).$(SENSOR_BOARD_VERSION).api_v$(SENSOR_HAL_API).$(SENSOR_FUSION_VERSION).$(SENSOR_FUSION_API))
endef

define _run_3rd_sensor_build
$(eval $(call _set_sensor_val,$(1)))
$(eval include $(2)/$(SENSOR_FUSION_VENDOR)/$(SENSOR_FUSION_VERSION)/Android.mk)
endef

define _run_tegra_sensor_build
$(eval $(call _set_sensor_val,$(1)))
$(eval subdir_makefiles := $(2)/build/$(SENSOR_BUILD_VERSION).api_v$(SENSOR_HAL_API)/Android.mk)
$(eval include $(2)/build/$(SENSOR_BUILD_VERSION).api_v$(SENSOR_HAL_API)/Android.mk)
endef

define _run_convert_tag_sensor_cfg
$(eval SENSOR_BUILD_TAG          := $(SENSOR_BUILD_TAG) $(1))
$(eval SENSOR_BOARD_VERSION_TAG  := $(SENSOR_BOARD_VERSION_TAG) $(call _add_tag_val,$(SENSOR_BOARD_VERSION),$(1)))
$(eval SENSOR_BUILD_VERSION_TAG  := $(SENSOR_BUILD_VERSION_TAG) $(call _add_tag_val,$(SENSOR_BUILD_VERSION),$(1)))
$(eval SENSOR_BUILD_CFLAGS_TAG   := $(SENSOR_BUILD_CFLAGS_TAG) $(call _add_tag_val,$(SENSOR_BUILD_CFLAGS),$(1)))
$(eval SENSOR_FUSION_VENDOR_TAG  := $(SENSOR_FUSION_VENDOR_TAG) $(call _add_tag_val,$(SENSOR_FUSION_VENDOR),$(1)))
$(eval SENSOR_FUSION_VERSION_TAG := $(SENSOR_FUSION_VERSION_TAG) $(call _add_tag_val,$(SENSOR_FUSION_VERSION),$(1)))
$(eval SENSOR_FUSION_API_TAG     := $(SENSOR_FUSION_API_TAG) $(call _add_tag_val,$(SENSOR_FUSION_API),$(1)))
$(eval SENSOR_FUSION_CFLAGS_TAG  := $(SENSOR_FUSION_CFLAGS_TAG) $(call _add_tag_val,$(SENSOR_FUSION_CFLAGS),$(1)))
$(eval SENSOR_FUSION_LIBRARIES_TAG := $(SENSOR_FUSION_LIBRARIES_TAG) $(call _add_tag_val,$(SENSOR_FUSION_LIBRARIES),$(1)))
$(eval SENSOR_HAL_VERSION_TAG    := $(SENSOR_HAL_VERSION_TAG) $(call _add_tag_val,$(SENSOR_HAL_VERSION),$(1)))
$(eval SENSOR_HAL_API_TAG        := $(SENSOR_HAL_API_TAG) $(call _add_tag_val,$(SENSOR_HAL_API),$(1)))
$(eval SENSOR_HAL_CFLAGS_TAG     := $(SENSOR_HAL_CFLAGS_TAG) $(call _add_tag_val,$(SENSOR_HAL_CFLAGS),$(1)))
$(eval SENSOR_HAL_LIBRARIES_TAG  := $(SENSOR_HAL_LIBRARIES_TAG) $(call _add_tag_val,$(SENSOR_HAL_LIBRARIES),$(1)))
$(eval SENSOR_HAL_OS_INTERFACE_SRC_TAG := $(SENSOR_HAL_OS_INTERFACE_SRC_TAG) $(call _add_tag_val,$(SENSOR_HAL_OS_INTERFACE_SRC),$(1)))
$(eval SENSOR_HAL_LOCAL_DRIVER_SRC_TAG := $(SENSOR_HAL_LOCAL_DRIVER_SRC_TAG) $(call _add_tag_val,$(SENSOR_HAL_LOCAL_DRIVER_SRC),$(1)))
$(eval SENSOR_REQUIRED_MODULES_TAG := $(SENSOR_REQUIRED_MODULES_TAG) $(call _add_tag_val,$(SENSOR_REQUIRED_MODULES),$(1)))
$(eval SENSOR_SHARED_LIBRARIES_TAG := $(SENSOR_SHARED_LIBRARIES_TAG) $(call _add_tag_val,$(SENSOR_SHARED_LIBRARIES),$(1)))
endef
