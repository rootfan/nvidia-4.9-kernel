ifeq ($(LOCAL_MODULE_CLASS),SHARED_LIBRARIES)
OVERRIDE_BUILT_MODULE_PATH := $($(LOCAL_2ND_ARCH_VAR_PREFIX)TARGET_OUT_INTERMEDIATE_LIBRARIES)
endif

# Disable clang for platform before Android-O for now.
ifeq ($(PLATFORM_IS_AFTER_N), 1)
# Enable/disable CLANG for nvmake
  ifneq ($(LOCAL_CLANG),false)
    NVIDIA_NVMAKE_ENABLE_CLANG := true
  else
    NVIDIA_NVMAKE_ENABLE_CLANG := false
  endif
else
  NVIDIA_NVMAKE_ENABLE_CLANG := false
endif

ifeq ($(TARGET_$(LOCAL_2ND_ARCH_VAR_PREFIX)ARCH),arm)
NVIDIA_NVMAKE_TARGET_ABI := _androideabi
NVIDIA_NVMAKE_TARGET_ARCH := ARMv7
else
NVIDIA_NVMAKE_TARGET_ABI :=
NVIDIA_NVMAKE_TARGET_ARCH := aarch64
endif

NVIDIA_NVMAKE_OUTPUT_ROOT := $(abspath $($(LOCAL_2ND_ARCH_VAR_PREFIX)TARGET_OUT_INTERMEDIATES)/NVMAKE/$(LOCAL_MODULE))

NVIDIA_NVMAKE_OUTPUT := \
    $(NVIDIA_NVMAKE_OUTPUT_ROOT)/Android_$(NVIDIA_NVMAKE_TARGET_ARCH)$(NVIDIA_NVMAKE_TARGET_ABI)_$(NVIDIA_NVMAKE_BUILD_TYPE)/$(LOCAL_NVIDIA_NVMAKE_BUILD_DIR)

NVIDIA_NVMAKE_MODULE := \
    $(NVIDIA_NVMAKE_OUTPUT)/$(NVIDIA_NVMAKE_MODULE_PRIVATE_PATH)/$(NVIDIA_NVMAKE_MODULE_NAME)$(LOCAL_MODULE_SUFFIX)


# Android builds set NV_INTERNAL_PROFILE in internal builds, and nothing
# on external builds. Convert this to nvmake convention.
ifeq ($(NV_INTERNAL_PROFILE),1)
NVIDIA_NVMAKE_PROFILE :
else
NVIDIA_NVMAKE_PROFILE := NVCFG_PROFILE=android_global_external_profile
endif

#
# Bring module from the nvmake build output, and apply the usual
# processing for shared library or executable.
#

include $(BUILD_SYSTEM)/dynamic_binary.mk

# dynamic_binary.mk includes $(BUILD_SYSTEM)/binary.mk
#           that includes $(BUILD_SYSTEM)/base_rules.mk
# it does not include  $(BUILD_SYSTEM)/shared_library_internal.mk nor $(BUILD_SYSTEM)/executable_internal.mk

my_static_libraries_dep := $(LOCAL_STATIC_LIBRARIES)
my_shared_libraries_dep := $(LOCAL_SHARED_LIBRARIES)
ifneq ($(LOCAL_USE_VNDK),)
    my_static_libraries_dep := $(foreach l,$(my_static_libraries_dep),\
      $(if $(SPLIT_VENDOR.STATIC_LIBRARIES.$(l)),$(l).vendor,$(l)))
    my_shared_libraries_dep := $(foreach l,$(my_shared_libraries_dep),\
      $(if $(SPLIT_VENDOR.SHARED_LIBRARIES.$(l)),$(l).vendor,$(l)))
endif

NVIDIA_NVMAKE_ADDITIONAL_DEPENDENCIES := \
       $(LOCAL_ADDITIONAL_DEPENDENCIES) \
       $(foreach l,$(my_shared_libraries_dep),$($(LOCAL_2ND_ARCH_VAR_PREFIX)TARGET_OUT_INTERMEDIATE_LIBRARIES)/$(l).so) \
       $(foreach l,$(my_static_libraries_dep),$(call intermediates-dir-for, \
         STATIC_LIBRARIES,$(l),,,$(LOCAL_2ND_ARCH_VAR_PREFIX))/$(l).a)

ifeq ($(PLATFORM_IS_AFTER_N), 1)
# Define PRIVATE_ variables from global vars
  ifeq ($(LOCAL_NO_LIBGCC),true)
    my_target_libgcc :=
  else
    my_target_libgcc := $(call intermediates-dir-for,STATIC_LIBRARIES,libgcc,,,$(LOCAL_2ND_ARCH_VAR_PREFIX))/libgcc.a
  endif
  my_target_libatomic := $(call intermediates-dir-for,STATIC_LIBRARIES,libatomic,,,$(LOCAL_2ND_ARCH_VAR_PREFIX))/libatomic.a
  ifeq ($(LOCAL_NO_CRT),true)
    #  Copied from $(BUILD_SYSTEM)/shared_library_internal.mk
    my_target_crtbegin_so_o :=
    my_target_crtend_so_o :=
    # Copied from $(BUILD_SYSTEM)/executable_internal.mk
    my_target_crtbegin_dynamic_o :=
    my_target_crtbegin_static_o :=
    my_target_crtend_o :=
  else ifdef LOCAL_USE_VNDK
    my_target_crtbegin_so_o := $($(LOCAL_2ND_ARCH_VAR_PREFIX)TARGET_OUT_INTERMEDIATE_LIBRARIES)/crtbegin_so.vendor.o
    my_target_crtend_so_o := $($(LOCAL_2ND_ARCH_VAR_PREFIX)TARGET_OUT_INTERMEDIATE_LIBRARIES)/crtend_so.vendor.o
    my_target_crtbegin_dynamic_o := $($(LOCAL_2ND_ARCH_VAR_PREFIX)TARGET_OUT_INTERMEDIATE_LIBRARIES)/crtbegin_dynamic.vendor.o
    my_target_crtbegin_static_o := $($(LOCAL_2ND_ARCH_VAR_PREFIX)TARGET_OUT_INTERMEDIATE_LIBRARIES)/crtbegin_static.vendor.o
    my_target_crtend_o := $($(LOCAL_2ND_ARCH_VAR_PREFIX)TARGET_OUT_INTERMEDIATE_LIBRARIES)/crtend_android.vendor.o
  else
    my_target_crtbegin_so_o := $($(LOCAL_2ND_ARCH_VAR_PREFIX)TARGET_OUT_INTERMEDIATE_LIBRARIES)/crtbegin_so.o
    my_target_crtend_so_o := $($(LOCAL_2ND_ARCH_VAR_PREFIX)TARGET_OUT_INTERMEDIATE_LIBRARIES)/crtend_so.o
    my_target_crtbegin_dynamic_o := $($(LOCAL_2ND_ARCH_VAR_PREFIX)TARGET_OUT_INTERMEDIATE_LIBRARIES)/crtbegin_dynamic.o
    my_target_crtbegin_static_o := $($(LOCAL_2ND_ARCH_VAR_PREFIX)TARGET_OUT_INTERMEDIATE_LIBRARIES)/crtbegin_static.o
    my_target_crtend_o := $($(LOCAL_2ND_ARCH_VAR_PREFIX)TARGET_OUT_INTERMEDIATE_LIBRARIES)/crtend_android.o
  endif
  ifneq ($(LOCAL_SDK_VERSION),)
    my_target_crtbegin_so_o := $(wildcard $(my_ndk_sysroot_lib)/crtbegin_so.o)
    my_target_crtend_so_o := $(wildcard $(my_ndk_sysroot_lib)/crtend_so.o)
  endif
else #ifeq ($(PLATFORM_IS_AFTER_N), 1)
  my_target_libgcc := $($(LOCAL_2ND_ARCH_VAR_PREFIX)TARGET_LIBGCC)
  my_target_crtbegin_so_o := $($(LOCAL_2ND_ARCH_VAR_PREFIX)TARGET_CRTBEGIN_SO_O)
  my_target_crtend_so_o := $($(LOCAL_2ND_ARCH_VAR_PREFIX)TARGET_CRTEND_SO_O)
  my_target_crtbegin_dynamic_o := $($(LOCAL_2ND_ARCH_VAR_PREFIX)TARGET_CRTBEGIN_DYNAMIC_O)
  my_target_crtend_o := $($(LOCAL_2ND_ARCH_VAR_PREFIX)TARGET_CRTEND_O)
endif

# add my_shared_libraries

$(linked_module): PRIVATE_TARGET_GLOBAL_LD_DIRS := $($(LOCAL_2ND_ARCH_VAR_PREFIX)TARGET_GLOBAL_LD_DIRS)
$(linked_module): PRIVATE_TARGET_LIBGCC := $(my_target_libgcc)
$(linked_module): PRIVATE_TARGET_CRTBEGIN_SO_O := $(my_target_crtbegin_so_o)
$(linked_module): PRIVATE_TARGET_CRTEND_SO_O := $(my_target_crtend_so_o)
$(linked_module): PRIVATE_TARGET_CRTBEGIN_DYNAMIC_O := $(my_target_crtbegin_dynamic_o)
$(linked_module): PRIVATE_TARGET_CRTBEGIN_STATIC_O := $(my_target_crtbegin_static_o)
$(linked_module): PRIVATE_TARGET_CRTEND_O := $(my_target_crtend_o)
$(linked_module): PRIVATE_TARGET_LIBATOMIC := $(my_target_libatomic)
$(linked_module): NVIDIA_NVMAKE_MODULE := $(NVIDIA_NVMAKE_MODULE)

ifeq ($(LOCAL_C_STD),)
    my_c_std_version := $(DEFAULT_C_STD_VERSION)
else ifeq ($(LOCAL_C_STD),experimental)
    my_c_std_version := $(EXPERIMENTAL_C_STD_VERSION)
else
    my_c_std_version := $(LOCAL_C_STD)
endif

my_c_std_conlyflags :=
my_cpp_std_cppflags :=
ifneq (,$(my_c_std_version))
    my_c_std_conlyflags := -std=$(my_c_std_version)
endif

ifneq (,$(my_cpp_std_version))
   my_cpp_std_cppflags := -std=$(my_cpp_std_version)
endif

ifeq ($(NVIDIA_NVMAKE_ENABLE_CLANG),true)
  my_target_global_cflags := $($(LOCAL_2ND_ARCH_VAR_PREFIX)CLANG_TARGET_GLOBAL_CFLAGS)
  my_target_global_conlyflags := $($(LOCAL_2ND_ARCH_VAR_PREFIX)CLANG_TARGET_GLOBAL_CONLYFLAGS) $(my_c_std_conlyflags)
  my_target_global_cppflags := $($(LOCAL_2ND_ARCH_VAR_PREFIX)CLANG_TARGET_GLOBAL_CPPFLAGS) $(my_cpp_std_cppflags)
  my_target_global_ldflags := $($(LOCAL_2ND_ARCH_VAR_PREFIX)CLANG_TARGET_GLOBAL_LDFLAGS)
else
  my_target_global_cflags := $($(LOCAL_2ND_ARCH_VAR_PREFIX)TARGET_GLOBAL_CFLAGS)
  my_target_global_conlyflags := $($(LOCAL_2ND_ARCH_VAR_PREFIX)TARGET_GLOBAL_CONLYFLAGS) $(my_c_std_conlyflags)
  my_target_global_cppflags := $($(LOCAL_2ND_ARCH_VAR_PREFIX)TARGET_GLOBAL_CPPFLAGS) $(my_cpp_std_cppflags)
  my_target_global_ldflags := $($(LOCAL_2ND_ARCH_VAR_PREFIX)TARGET_GLOBAL_LDFLAGS)
endif

$(linked_module): PRIVATE_TARGET_OUT_INTERMEDIATE_LIBRARIES := $($(LOCAL_2ND_ARCH_VAR_PREFIX)TARGET_OUT_INTERMEDIATE_LIBRARIES)
$(linked_module): PRIVATE_GLOBAL_C_INCLUDES := $(my_target_global_c_includes)
$(linked_module): PRIVATE_GLOBAL_C_SYSTEM_INCLUDES := $(my_target_global_c_system_includes)
$(linked_module): PRIVATE_TARGET_GLOBAL_CFLAGS := $(my_target_global_cflags)
$(linked_module): PRIVATE_TARGET_GLOBAL_CONLYFLAGS := $(my_target_global_conlyflags)
$(linked_module): PRIVATE_TARGET_GLOBAL_CPPFLAGS := $(my_target_global_cppflags)
$(linked_module): PRIVATE_TARGET_GLOBAL_LDFLAGS := $(my_target_global_ldflags)

#
# Call into the nvmake build system to build the module
#
# Add NVUB_SUPPORTS_TXXX=1 to temporarily enable a chip
#

LOCAL_NVIDIA_NVMAKE_ARGS += \
    TARGET_OUT_INTERMEDIATE_LIBRARIES=$(abspath $($(LOCAL_2ND_ARCH_VAR_PREFIX)TARGET_OUT_INTERMEDIATE_LIBRARIES)) \
    TARGET_LIBGCC=$($(LOCAL_2ND_ARCH_VAR_PREFIX)TARGET_LIBGCC)

# CLANG specific definitions to interface with nvmake.
ifeq ($(NVIDIA_NVMAKE_ENABLE_CLANG),true)

# clang always needs a target tuple for cross compilation.
ifeq ($(TARGET_$(LOCAL_2ND_ARCH_VAR_PREFIX)ARCH),arm)
  CLANG_TARGET_TRIPLE := arm-linux-androideabi
else ifeq ($(TARGET_$(LOCAL_2ND_ARCH_VAR_PREFIX)ARCH),arm64)
  CLANG_TARGET_TRIPLE := aarch64-linux-android
else
  $(error Unsupported CLANG_TARGET = $(TARGET_$(LOCAL_2ND_ARCH_VAR_PREFIX)ARCH))
endif

$(linked_module): NVIDIA_NVMAKE_CLANG_BUILD_PARAMS := \
    NV_CLANG_ANDROID_TARGET=$(CLANG_TARGET_TRIPLE) \
    NV_TARGET_CLANG_PREBUILTS_PATH=$(abspath $(LLVM_PREBUILTS_PATH)) \
    NV_TARGET_GLOBAL_CFLAGS="$(PRIVATE_TARGET_GLOBAL_CFLAGS)" \
    NV_TARGET_GLOBAL_CPPFLAGS="$(PRIVATE_TARGET_GLOBAL_CPPFLAGS)" \
    NV_TARGET_GLOBAL_LDFLAGS="$(PRIVATE_TARGET_GLOBAL_LDFLAGS)"

$(linked_module): PRIVATE_EXTRA_LDFLAGS :=
else
$(linked_module): NVIDIA_NVMAKE_CLANG_BUILD_PARAMS :=
# The Aarch64 uses ld instead of gold as a linker. ld doesn't support gc-sections
ifeq ($($(LOCAL_2ND_ARCH_VAR_PREFIX)TARGET_ARCH),arm)
$(linked_module): PRIVATE_EXTRA_LDFLAGS := -Wl,--gc-sections
else
$(linked_module): PRIVATE_EXTRA_LDFLAGS :=
endif
endif

$(linked_module): NVIDIA_NVMAKE_COMMON_BUILD_PARAMS := \
    TEGRA_TOP=$(abspath $(TEGRA_TOP)) \
    ANDROID_BUILD_TOP=$(ANDROID_BUILD_TOP) \
    OUT=$(PRODUCT_OUT) \
    NV_OUTPUT_ROOT=$(NVIDIA_NVMAKE_OUTPUT_ROOT) \
    NV_SOURCE=$(NVIDIA_NVMAKE_TOP) \
    NV_TOOLS=$(P4ROOT)/sw/tools \
    NV_HOST_OS=Linux \
    NV_HOST_ARCH=x86 \
    $(NVIDIA_NVMAKE_CLANG_BUILD_PARAMS) \
    NV_TARGET_OS=Android \
    NV_TARGET_ARCH=$(NVIDIA_NVMAKE_TARGET_ARCH) \
    NV_BUILD_TEGRA=1 \
    NV_BUILD_TYPE=$(NVIDIA_NVMAKE_BUILD_TYPE) \
    $(NVIDIA_NVMAKE_PROFILE) \
    NV_COVERAGE_ENABLED=$(NVIDIA_COVERAGE_ENABLED) \
    TARGET_TOOLS_PREFIX=$(abspath $($(LOCAL_2ND_ARCH_VAR_PREFIX)TARGET_TOOLS_PREFIX)) \
    TARGET_C_INCLUDES="$(foreach inc, $(LOCAL_NVIDIA_STL_INCLUDES) $(PRIVATE_GLOBAL_C_SYSTEM_INCLUDES) $(PRIVATE_GLOBAL_C_INCLUDES) $(PRIVATE_TARGET_C_INCLUDES) $($(LOCAL_2ND_ARCH_VAR_PREFIX)TARGET_C_INCLUDES), $(abspath $(inc)))" \
    TARGET_GLOBAL_CFLAGS="$($(LOCAL_2ND_ARCH_VAR_PREFIX)TARGET_GLOBAL_CFLAGS) -Wno-attributes" \
    $(NVUB_SUPPORTS_FLAG_LIST) \
    $(NVIDIA_NVMAKE_VERBOSE) \
    $(NVIDIA_NVMAKE_GUARDWORD) \
    $(NVIDIA_NVMAKE_EXTRADEFS) \
    $(LOCAL_NVIDIA_NVMAKE_ARGS)

$(linked_module): _nvmake_gen_android_ldflags = \
    $(1) \
    -nostdlib \
    $(PRIVATE_EXTRA_LDFLAGS) \
    $(2) \
    $(patsubst -L%,-L$(abspath $(TOP))/%,$(PRIVATE_TARGET_GLOBAL_LD_DIRS)) \
    $(abspath $(3)) \
    -Wl,--whole-archive \
    $(call normalize-abspath-libraries,$(PRIVATE_ALL_WHOLE_STATIC_LIBRARIES)) \
    -Wl,--no-whole-archive \
    $(call normalize-abspath-libraries,$(PRIVATE_ALL_STATIC_LIBRARIES)) \
    $(addprefix -L,$(abspath $(PRIVATE_TARGET_OUT_INTERMEDIATE_LIBRARIES))) \
    $(call normalize-abspath-libraries,$(PRIVATE_ALL_SHARED_LIBRARIES)) \
    $(PRIVATE_LDFLAGS) \
    $(PRIVATE_TARGET_GLOBAL_LDFLAGS) \
    $(abspath $(PRIVATE_TARGET_LIBGCC)) \
    $(abspath $(4))

$(linked_module): NVIDIA_NVMAKE_BUILD_PARAMS = \
    $(NVIDIA_NVMAKE_COMMON_BUILD_PARAMS) \
    TARGET_C_INCLUDES+="$(shell cat $(abspath $(TOP))/$(PRIVATE_IMPORT_INCLUDES) | sed -e 's@-I\s*@$(abspath $(TOP))\/@g' -e 's@-isystem \+@$(abspath $(TOP))\/@g' | tr '\r\n' ' ')" \
    ANDROID_IMPORT_INCLUDES="$(shell cat $(abspath $(TOP))/$(PRIVATE_IMPORT_INCLUDES) | sed -e 's@-I\s*@-I$(subst /,\/,$(abspath $(TOP)))\/@g' -e 's@-isystem \+@-isystem $(subst /,\/,$(abspath $(TOP)))\/@g' | tr '\r\n' ' ')" \
    ANDROID_DSO_LDFLAGS="$(call _nvmake_gen_android_ldflags,\
                 ,\
                 -Wl$(comma)-shared$(comma)-Bsymbolic,\
                 $(PRIVATE_TARGET_CRTBEGIN_SO_O),\
                 $(PRIVATE_TARGET_CRTEND_SO_O))" \
    ANDROID_BIN_LDFLAGS="$(call _nvmake_gen_android_ldflags,\
                 -pie -fPIE,\
                 -Wl$(comma)-Bdynamic,\
                 $(PRIVATE_TARGET_CRTBEGIN_DYNAMIC_O),\
                 $(PRIVATE_TARGET_CRTEND_O))"

ifeq ($(NV_USE_UNIX_BUILD),1)
  ifneq ($(NVIDIA_NVMAKE_EXTERNAL_DRIVER_SOURCE),)
    $(linked_module): NV_NVMAKE_EXTERNAL_DRIVER = --external-driver $(NVIDIA_NVMAKE_EXTERNAL_DRIVER_SOURCE)
  else
    $(linked_module): NV_NVMAKE_EXTERNAL_DRIVER =
  endif

  $(linked_module): NVIDIA_NVMAKE_COMMAND := \
    $(NVIDIA_NVMAKE_UNIX_BUILD_COMMAND) \
    --envvar "GCC_COLORS=$$GCC_COLORS" \
    --envvar "MAKEFLAGS=$$(echo $$MAKEFLAGS | sed -e 's/ -- .*$$//')" \
    --envvar "MAKELEVEL=$$MAKELEVEL" \
    --envvar MAKE=$(abspath $(TEGRA_TOP))/core-private/tools/make-3.81/prebuilt/linux-x86_64/make \
    $(NV_NVMAKE_EXTERNAL_DRIVER) \
    --newdir $(NVIDIA_NVMAKE_TOP)/$(LOCAL_NVIDIA_NVMAKE_BUILD_DIR) \
    $(abspath $(TEGRA_TOP))/core-private/tools/make-3.81/prebuilt/linux-x86_64/make \
    -f makefile.nvmk
else
  $(linked_module): NVIDIA_NVMAKE_COMMAND := \
    $(MAKE) \
    MAKE=$(shell which $(MAKE)) \
    LD_LIBRARY_PATH=$(NVIDIA_NVMAKE_LIBRARY_PATH) \
    NV_UNIX_BUILD_CHROOT=$(P4ROOT)/sw/tools/unix/hosts/Linux-x86/unix-build \
    -C $(NVIDIA_NVMAKE_TOP)/$(LOCAL_NVIDIA_NVMAKE_BUILD_DIR) \
    -f makefile.nvmk

  ifneq ($(NVIDIA_NVMAKE_EXTERNAL_DRIVER_SOURCE),)
    $(linked_module): NVIDIA_NVMAKE_COMMAND += NV_EXTERNAL_DRIVER_SOURCE=$(NVIDIA_NVMAKE_EXTERNAL_DRIVER_SOURCE)
  endif
endif

# This target needs to be forced, nvmake will do its own dependency checking
$(linked_module): $(intermediates)/import_includes $(NVIDIA_NVMAKE_ADDITIONAL_DEPENDENCIES) $(my_target_crtbegin_so_o) $(my_target_crtend_so_o) FORCE | $(ACP)
	@echo "Build with nvmake: $(PRIVATE_MODULE) ($@)"
	@echo "PRIVATE_TARGET_GLOBAL_LD_DIRS: ($(PRIVATE_TARGET_GLOBAL_LD_DIRS))"
	+$(hide) $(NVIDIA_NVMAKE_COMMAND) $(NVIDIA_NVMAKE_BUILD_PARAMS)
	@mkdir -p $(dir $@)
	$(hide) $(ACP) -fp $(NVIDIA_NVMAKE_MODULE) $@

#
# Make the module's clean target clean the output directory
#

$(cleantarget) : PRIVATE_NVMAKE_OUTPUT := $(NVIDIA_NVMAKE_OUTPUT)
$(cleantarget)::
	$(hide) rm -r $(PRIVATE_NVMAKE_OUTPUT)

NVIDIA_NVMAKE_OUTPUT :=
NVIDIA_NVMAKE_OUTPUT_ROOT :=
NVIDIA_NVMAKE_MODULE :=
NVIDIA_NVMAKE_TARGET_ABI :=
NVIDIA_NVMAKE_TARGET_ARCH :=
NVIDIA_NVMAKE_ADDITIONAL_DEPENDENCIES :=
NVIDIA_NVMAKE_PROFILE :=
