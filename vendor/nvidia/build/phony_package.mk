NVIDIA_TEMPLATE_SUPPORTS_BUILD_MODULARIZATION := true

ifeq ($(NVIDIA_BUILD_MODULARIZATION_IS_STUBBED),1)
  #
  # Stubbed implementation
  #
  $(nvidia_build_modularization_stub_filter_locals)
endif

include $(NVIDIA_BASE)

# Android does not setup vendor directories for FAKE class. As nothing gets
# installed anyway we can simply disable the vendor flag for phony packages.
LOCAL_PROPRIETARY_MODULE := false

include $(BUILD_PHONY_PACKAGE)
include $(NVIDIA_POST)
