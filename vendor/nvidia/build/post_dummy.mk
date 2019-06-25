# This file should be included in cases where NVIDIA_DEFAULTS
# is included, but we want to skip the build

# This file can be included without including NVIDIA_BASE
ifeq ($(NVIDIA_CLEARED),false)
$(error $(LOCAL_PATH): NVIDIA variables not cleared)
endif
NVIDIA_CLEARED := false

ifeq ($(NVIDIA_POST_INCLUDED),true)
$(error $(LOCAL_PATH):$(LOCAL_MODULE): NVIDIA_POST included twice)
endif
NVIDIA_POST_INCLUDED := true

include $(NVIDIA_BUILD_MODULARIZATION_CLEAR)
