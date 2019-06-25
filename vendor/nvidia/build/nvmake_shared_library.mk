NVIDIA_TEMPLATE_SUPPORTS_BUILD_MODULARIZATION := true

# Try guessing the .export file if not given
ifeq ($(LOCAL_NVIDIA_EXPORTS),)
LOCAL_NVIDIA_EXPORTS := $(subst $(LOCAL_PATH)/,,$(strip $(wildcard $(LOCAL_PATH)/$(LOCAL_MODULE)_*.export) $(wildcard $(LOCAL_PATH)/$(LOCAL_MODULE).export)))
endif

ifdef NVIDIA_BUILD_MODULARIZATION_NAME
  ifeq ($(LOCAL_NVIDIA_EXPORTS),)
    # All modularized shared libraries must have an export file.
    # This is required to build a stub in the system builder (as well as any
    # stubs that other build modules may link against).
    $(error $(LOCAL_MODULE_MAKEFILE): Part of build module $(NVIDIA_BUILD_MODULARIZATION_NAME), export file required for shared library)
  endif
endif

ifeq ($(NVIDIA_BUILD_MODULARIZATION_IS_STUBBED),1)

#
# Stubbed implementation
# Bypass nvmake and handle like any other NV shared library.
#
include $(NVIDIA_SHARED_LIBRARY)

else

LOCAL_MODULE_CLASS := SHARED_LIBRARIES
LOCAL_MODULE_SUFFIX := $(TARGET_SHLIB_SUFFIX)

ifneq ($(LOCAL_MODULE_PATH),)
ifneq ($(TARGET_2ND_ARCH),)
$(warning $(LOCAL_MODULE): LOCAL_MODULE_PATH for shared libraries is unsupported in multiarch builds, use LOCAL_MODULE_RELATIVE_PATH instead)
endif
endif

ifneq ($(LOCAL_UNSTRIPPED_PATH),)
ifneq ($(TARGET_2ND_ARCH),)
$(warning $(LOCAL_MODULE): LOCAL_UNSTRIPPED_PATH for shared libraries is unsupported in multiarch builds)
endif
endif

include $(BUILD_SYSTEM)/multilib.mk

ifndef my_module_multilib
# libraries default to building for both architectures
my_module_multilib := both
endif

include $(NVIDIA_NVMAKE_BASE)

LOCAL_2ND_ARCH_VAR_PREFIX :=
include $(BUILD_SYSTEM)/module_arch_supported.mk

ifeq ($(my_module_arch_supported),true)
include $(NVIDIA_NVMAKE_INTERNAL)
endif

ifdef TARGET_2ND_ARCH

LOCAL_2ND_ARCH_VAR_PREFIX := $(TARGET_2ND_ARCH_VAR_PREFIX)
include $(BUILD_SYSTEM)/module_arch_supported.mk

ifeq ($(my_module_arch_supported),true)
# Build for TARGET_2ND_ARCH
OVERRIDE_BUILT_MODULE_PATH :=
LOCAL_BUILT_MODULE :=
LOCAL_INSTALLED_MODULE :=
LOCAL_MODULE_STEM :=
LOCAL_BUILT_MODULE_STEM :=
LOCAL_INSTALLED_MODULE_STEM :=
LOCAL_INTERMEDIATE_TARGETS :=

include $(NVIDIA_NVMAKE_INTERNAL)

endif

LOCAL_2ND_ARCH_VAR_PREFIX :=

endif # TARGET_2ND_ARCH

include $(NVIDIA_POST)

my_module_arch_supported :=

endif

include $(NVIDIA_NVMAKE_CLEAR)
