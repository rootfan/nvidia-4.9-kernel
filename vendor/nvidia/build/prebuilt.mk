NVIDIA_TEMPLATE_SUPPORTS_BUILD_MODULARIZATION := true

ifeq ($(LOCAL_MODULE_CLASS),)
$(error $(NVIDIA_MAKEFILE): empty LOCAL_MODULE_CLASS is not allowed))
endif

#All prebuilts that aren't used in the build process will be stubbed
#in modular builds. This is in order to
# -avoid triggering unnecessary rebuilds when prebuilts are changed
# -save space
ifneq ($(LOCAL_MODULE_CLASS),STATIC_LIBRARIES)
  ifeq ($(NVIDIA_BUILD_MODULARIZATION_IS_STUBBED),1)
    #
    # Stubbed implementation
    #
    ifeq ($(LOCAL_NVIDIA_PREBUILT_DISABLE_STUB),1)
      # Use prebuilt as other components depend on the real thing
      NVIDIA_BUILD_MODULARIZATION_STUB_NEEDS_LOCALS += \
        LOCAL_SRC_FILES
      $(nvidia_build_modularization_stub_filter_locals)

    else
      $(nvidia_build_modularization_stub_filter_locals)

      # Generate empty stub prebuilt
      GEN := $(local-generated-sources-dir)/$(LOCAL_MODULE)

      $(GEN): PRIVATE_CUSTOM_TOOL = touch $@
      $(GEN):
		$(transform-generated-source)

      LOCAL_PREBUILT_MODULE_FILE := $(GEN)

      # strip will fail on the empty stub
      LOCAL_STRIP_MODULE := false
    endif
  endif
endif

include $(BUILD_SYSTEM)/multilib.mk

ifdef LOCAL_IS_HOST_MODULE
ifndef LOCAL_MODULE_HOST_ARCH
ifndef my_module_multilib
#ifneq ($(LOCAL_MODULE_CLASS),EXECUTABLES)
ifneq ($(findstring $(LOCAL_MODULE_CLASS),STATIC_LIBRARIES SHARED_LIBRARIES),)
    ifeq ($(HOST_PREFER_32_BIT),true)
        LOCAL_MULTILIB := 32
    else
    # By default we only build host module for the first arch.
        LOCAL_MULTILIB := first
    endif # HOST_PREFER_32_BIT
endif # EXECUTABLES STATIC_LIBRARIES SHARED_LIBRARIES
endif
endif
endif

include $(NVIDIA_BASE)

ifeq ($(PLATFORM_IS_AFTER_LOLLIPOP),1)
ifneq ($(filter %.py,$(LOCAL_SRC_FILES)),)
LOCAL_STRIP_MODULE := false
endif
endif

include $(BUILD_PREBUILT)
include $(NVIDIA_POST)
