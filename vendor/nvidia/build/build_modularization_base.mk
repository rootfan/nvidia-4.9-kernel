# Define how to build stubs in the different flavors of modularized and
# non-modularized builds.
#
# NVIDIA_BUILD_MODULARIZATION_NAME;
# Set to the name of the build module for the current target. Empty for
# components that have not yet been modularized.
#
# NVIDIA_BUILD_MODULARIZATION_IS_STUBBED:
# When this is set to 1, we build a stub for the current target.
#
# NVIDIA_BUILD_MODULARIZATION_CUT_STUB_DEPENDENCIES:
# When this is set to 1, we cut the dependency tree whenever we encounter a stub.
# - We use value 1 in module builders to keep them and their manifests as lean as possible.
# - We use value 0 in the system builder to ensure that every binary that would have
#   been installed in a non-modular build is also installed (as a real implementation or
#   a stub) in the system builder.

NVIDIA_BUILD_MODULARIZATION_NAME := $(nvidia_get_build_modularization_name)

ifdef NVIDIA_BUILD_MODULARIZATION_NAME
  # We're in a modularized component
  ifdef BUILD_BRAIN_MODULAR_NAME
    # Module builder
    ifeq ($(NVIDIA_BUILD_MODULARIZATION_NAME),$(BUILD_BRAIN_MODULAR_NAME))
      # Module builder for NVIDIA_BUILD_MODULARIZATION_NAME
      NVIDIA_BUILD_MODULARIZATION_IS_STUBBED := 0
    else
      # Module builder for another module
      NVIDIA_BUILD_MODULARIZATION_IS_STUBBED := 1
    endif
  else
    ifeq ($(findstring $(NVIDIA_BUILD_MODULARIZATION_NAME),$(BUILD_BRAIN_MODULAR_COMPONENTS)),)
      # (a) Non-modular build
      # (b) System builder with NVIDIA_BUILD_MODULARIZATION_NAME *NOT* enabled
      NVIDIA_BUILD_MODULARIZATION_IS_STUBBED := 0
    else
      # System builder with NVIDIA_BUILD_MODULARIZATION_NAME enabled
      NVIDIA_BUILD_MODULARIZATION_IS_STUBBED := 1
    endif
  endif
else
  # We're in a component that was not yet modularized
  ifdef BUILD_BRAIN_MODULAR_NAME
    # Module builder
    NVIDIA_BUILD_MODULARIZATION_IS_STUBBED := 1
  else
    # Non-modular build or system builder
    NVIDIA_BUILD_MODULARIZATION_IS_STUBBED := 0
  endif
endif

ifdef BUILD_BRAIN_MODULAR_NAME
  # Module builder
  NVIDIA_BUILD_MODULARIZATION_CUT_STUB_DEPENDENCIES := 1
else
  # Non-modular build or system builder
  NVIDIA_BUILD_MODULARIZATION_CUT_STUB_DEPENDENCIES := 0
endif

NVIDIA_BUILD_MODULARIZATION_STUB_NEEDS_LOCALS := \
  NVIDIA_MAKEFILE \
  LOCAL_INSTALLED_MODULE_STEM \
  LOCAL_MODULE \
  LOCAL_MODULE_TARGET_ARCH \
  LOCAL_MODULE_TARGET_ARCH_WARN \
  LOCAL_MODULE_UNSUPPORTED_TARGET_ARCH \
  LOCAL_MODULE_UNSUPORTED_TARGET_ARCH_WARN \
  LOCAL_MODULE_HOST_ARCH \
  LOCAL_MODULE_CLASS \
  LOCAL_MODULE_PATH \
  LOCAL_MODULE_RELATIVE_PATH \
  LOCAL_MODULE_TAGS \
  LOCAL_MODULE_STEM \
  LOCAL_MODULE_SUFFIX \
  LOCAL_MODULE_PATH_32 \
  LOCAL_MODULE_PATH_64 \
  LOCAL_MODULE_STEM_32 \
  LOCAL_MODULE_STEM_64 \
  LOCAL_32_BIT_ONLY \
  LOCAL_EXPORT_C_INCLUDE_DIRS \
  LOCAL_IS_HOST_MODULE \
  LOCAL_MULTILIB \
  LOCAL_STRIP_MODULE

ifeq ($(NVIDIA_BUILD_MODULARIZATION_IS_STUBBED),1)
  ifeq ($(NVIDIA_BUILD_MODULARIZATION_CUT_STUB_DEPENDENCIES),0)
    NVIDIA_BUILD_MODULARIZATION_STUB_NEEDS_LOCALS += \
      LOCAL_REQUIRED_MODULES \
      LOCAL_SHARED_LIBRARIES \
      LOCAL_SHARED_LIBRARIES_$(TARGET_ARCH) \
      LOCAL_REQUIRED_MODULES_$(TARGET_ARCH) \
      LOCAL_SHARED_LIBRARIES_$(HOST_ARCH) \
      LOCAL_REQUIRED_MODULES_$(HOST_ARCH) \
      LOCAL_SHARED_LIBRARIES_32 \
      LOCAL_SHARED_LIBRARIES_64
    ifdef TARGET_2ND_ARCH
      NVIDIA_BUILD_MODULARIZATION_STUB_NEEDS_LOCALS += \
        LOCAL_SHARED_LIBRARIES_$(TARGET_2ND_ARCH) \
        LOCAL_REQUIRED_MODULES_$(TARGET_2ND_ARCH)
    endif
    ifdef HOST_2ND_ARCH
      NVIDIA_BUILD_MODULARIZATION_STUB_NEEDS_LOCALS += \
        LOCAL_SHARED_LIBRARIES_$(HOST_2ND_ARCH) \
        LOCAL_REQUIRED_MODULES_$(HOST_2ND_ARCH)
    endif
  endif
endif

NVIDIA_BUILD_MODULARIZATION_CUT_STUB_DEPENDENCIES :=
