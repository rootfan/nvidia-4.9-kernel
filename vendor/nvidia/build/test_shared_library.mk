NVIDIA_TEMPLATE_SUPPORTS_BUILD_MODULARIZATION := true

ifneq ($(LOCAL_NVIDIA_EXPORTS),)
  $(error $(LOCAL_MODULE_MAKEFILE): LOCAL_NVIDIA_EXPORTS not allowed, the export file is provided by the template)
endif

LOCAL_MODULE_TAGS    := nvidia_tests
LOCAL_NVIDIA_EXPORTS := $(abspath $(TEGRA_TOP))/core-private/utils/nvtestrun/nvtest.export

# test shared libraries aren't named with a "lib" prefix, which prevents the
# apicheck from linking against them.
NVIDIA_APICHECK := false

include $(NVIDIA_SHARED_LIBRARY)
