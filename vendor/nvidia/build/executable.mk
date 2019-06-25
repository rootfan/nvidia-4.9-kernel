NVIDIA_TEMPLATE_SUPPORTS_BUILD_MODULARIZATION := true

LOCAL_MODULE_CLASS := EXECUTABLES

ifeq ($(NVIDIA_BUILD_MODULARIZATION_IS_STUBBED),1)
  #
  # Stubbed implementation
  #
  $(nvidia_build_modularization_stub_filter_locals)

  LOCAL_SYSTEM_SHARED_LIBRARIES := libc

  # Generate minimal C file to compile
  GEN := $(local-generated-sources-dir)/$(LOCAL_MODULE).c

  $(GEN): PRIVATE_CUSTOM_TOOL = echo "int main(int argc, char **argv) { return 1; }" > $@
  $(GEN):
	$(transform-generated-source)

  LOCAL_GENERATED_SOURCES := $(GEN)
endif

include $(NVIDIA_BASE)
include $(NVIDIA_WARNINGS)
include $(NVIDIA_COVERAGE)
include $(BUILD_EXECUTABLE)
include $(NVIDIA_POST)
