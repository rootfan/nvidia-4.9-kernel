LOCAL_MODULE_CLASS := SHARED_LIBRARIES
LOCAL_IS_HOST_MODULE := true

include $(BUILD_SYSTEM)/multilib.mk

ifndef LOCAL_MODULE_HOST_ARCH
ifndef my_module_multilib
    ifeq ($(HOST_PREFER_32_BIT),true)
        my_module_multilib := 32
    else
    # By default we only build host module for the first arch.
        my_module_multilib := first
    endif # HOST_PREFER_32_BIT
endif
endif

include $(NVIDIA_BASE)
LOCAL_LDFLAGS += -Wl,--build-id=sha1
include $(NVIDIA_COVERAGE)
include $(BUILD_HOST_SHARED_LIBRARY)
include $(NVIDIA_POST)
