NVIDIA_TEMPLATE_SUPPORTS_BUILD_MODULARIZATION := true
# Only support test files in /data
ifneq ($(LOCAL_MODULE_PATH),)
$(error $(LOCAL_MODULE_MAKEFILE): $(LOCAL_MODULE): Use LOCAL_MODULE_RELATIVE_PATH instead of LOCAL_MODULE_PATH)
endif
ifneq ($(findstring ..,$(LOCAL_MODULE_RELATIVE_PATH) $(LOCAL_SRC_FILES)),)
$(error $(LOCAL_MODULE_MAKEFILE): $(LOCAL_MODULE): Do not use '..' - only install test files to /data/... or the host)
endif

ifeq ($(LOCAL_IS_HOST_MODULE),true)
  LOCAL_MODULE_PATH := $(HOST_OUT)/usr/$(LOCAL_MODULE_RELATIVE_PATH)
else
  LOCAL_MODULE_PATH := $(TARGET_OUT_DATA)/$(LOCAL_MODULE_RELATIVE_PATH)
endif

# Prepend $(LOCAL_PATH) to src
# Prepend $(LOCAL_MODULE_PATH) to dest
# If dest is empty, use filename of src
LOCAL_SRC_FILES := $(foreach f,$(LOCAL_SRC_FILES), \
    $(eval _src := $(call word-colon,1,$(f))) \
    $(eval _dst := $(call word-colon,2,$(f))) \
    $(eval _out := $(LOCAL_PATH)/$(_src):$(LOCAL_MODULE_PATH)/$(or $(_dst), $(notdir $(_src)))) \
    $(_out))

# Expand directories, copy-many-files only handles files
LOCAL_SRC_FILES := $(foreach f,$(LOCAL_SRC_FILES), \
    $(eval _src := $(call word-colon,1,$(f))) \
    $(eval _dst := $(call word-colon,2,$(f))) \
    $(eval _srcs := $(shell find $(_src) -type f $(LOCAL_NVIDIA_FIND_FILTER))) \
    $(eval _out := $(foreach fs,$(_srcs), \
        $(fs):$(_dst)$(patsubst $(_src)%,%,$(fs)))) \
    $(_out))

LOCAL_MODULE_TAGS := nvidia_tests
LOCAL_IS_HOST_MODULE :=
LOCAL_MODULE_CLASS := FAKE

# Modular builds need stubs and/or modular markers.
$(eval _stub := $(filter 1,$(NVIDIA_BUILD_MODULARIZATION_IS_STUBBED)))
$(eval _marker := $(if $(_stub),1,$(BUILD_BRAIN_MODULAR_NAME)))

ALL_NVIDIA_MODULES.$(LOCAL_MODULE).INSTALLED_FILES := $(LOCAL_SRC_FILES)
LOCAL_SRC_FILES := $(foreach f,$(LOCAL_SRC_FILES), \
    $(eval _src := $(call word-colon,1,$(f))) \
    $(eval _gen := $(local-generated-sources-dir)/$(_src)) \
    $(eval $(call nvidia-generate-empty-file,$(_gen))) \
    $(eval _dst := $(call word-colon,2,$(f))) \
    $(eval _out := $(if $(_stub),$(_gen),$(_src)):$(_dst)) \
    $(eval _out_marker := $(if $(_marker),$(_gen):$(_dst).modular_$(if $(_stub),stub,real))) \
    $(_out) $(_out_marker))

installed_files := $(call copy-many-files,$(LOCAL_SRC_FILES))

$(if $(_stub),$(nvidia_build_modularization_stub_filter_locals))

LOCAL_ADDITIONAL_DEPENDENCIES += $(installed_files)

include $(BUILD_SYSTEM)/multilib.mk
include $(NVIDIA_BASE)

LOCAL_SRC_FILES :=
LOCAL_MODULE_PATH :=
LOCAL_MODULE_RELATIVE_PATH :=
LOCAL_PROPRIETARY_MODULE := false

include $(BUILD_PHONY_PACKAGE)

$(cleantarget) : PRIVATE_CLEAN_FILES += $(installed_files)

include $(NVIDIA_POST)
