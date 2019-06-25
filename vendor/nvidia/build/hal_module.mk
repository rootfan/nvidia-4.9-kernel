NVIDIA_TEMPLATE_SUPPORTS_BUILD_MODULARIZATION := true

ifneq ($(LOCAL_NVIDIA_EXPORTS),)
  $(error $(LOCAL_MODULE_MAKEFILE): LOCAL_NVIDIA_EXPORTS not allowed, the export file is provided by the template)
endif

LOCAL_NVIDIA_EXPORTS := $(abspath $(NVIDIA_BUILD_ROOT))/hal_module.export

# Hal modules aren't named with a "lib" prefix, which prevents the apicheck
# from linking against them.
NVIDIA_APICHECK := false

include $(NVIDIA_SHARED_LIBRARY)

