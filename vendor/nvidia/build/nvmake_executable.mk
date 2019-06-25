NVIDIA_TEMPLATE_SUPPORTS_BUILD_MODULARIZATION := true

ifeq ($(NVIDIA_BUILD_MODULARIZATION_IS_STUBBED),1)

  # Stubbed implementation
  # Bypass nvmake and handle like any other NV executable.
  include $(NVIDIA_EXECUTABLE)

else

  LOCAL_MODULE_CLASS := EXECUTABLES

  include $(BUILD_SYSTEM)/multilib.mk
  ifndef my_module_multilib
    # executables default to building for the first architecture
    my_module_multilib := first
  endif

  include $(NVIDIA_NVMAKE_BASE)

  # first architecture
  LOCAL_2ND_ARCH_VAR_PREFIX :=
  include $(BUILD_SYSTEM)/module_arch_supported.mk
  ifeq ($(my_module_arch_supported),true)
    include $(NVIDIA_NVMAKE_INTERNAL)
  endif

  # second architecture
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
  endif

  include $(NVIDIA_POST)
  my_module_arch_supported :=
endif
