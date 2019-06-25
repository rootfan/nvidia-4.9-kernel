NVIDIA_TEMPLATE_SUPPORTS_BUILD_MODULARIZATION := true

LOCAL_MODULE_CLASS := STATIC_LIBRARIES

# Do not include default libc etc
LOCAL_SYSTEM_SHARED_LIBRARIES :=

include $(BUILD_SYSTEM)/multilib.mk

ifndef my_module_multilib
# libraries default to building for both architectures
my_module_multilib := both
endif

include $(NVIDIA_BASE)
include $(NVIDIA_WARNINGS)
include $(NVIDIA_COVERAGE)
include $(BUILD_STATIC_LIBRARY)
include $(NVIDIA_POST)
