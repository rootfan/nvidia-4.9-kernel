NVIDIA_TEMPLATE_SUPPORTS_BUILD_MODULARIZATION := true

LOCAL_MODULE_CLASS := EXECUTABLES
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

ifeq ($(NVIDIA_BUILD_MODULARIZATION_IS_STUBBED),1)
  #
  # Stubbed implementation
  #
  $(nvidia_build_modularization_stub_filter_locals)

  # Generate minimal C file to compile
  GEN := $(local-generated-sources-dir)/$(LOCAL_MODULE).c

  $(GEN): PRIVATE_CUSTOM_TOOL = echo "int main(int argc, char **argv) { return 1; }" > $@
  $(GEN):
	$(transform-generated-source)

  LOCAL_GENERATED_SOURCES := $(GEN)
endif

include $(NVIDIA_BASE)
include $(NVIDIA_COVERAGE)
include $(BUILD_HOST_EXECUTABLE)
include $(NVIDIA_POST)
