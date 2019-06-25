# NVIDIA TegraShield factory development system
#
# Copyright (c) 2013-2017 NVIDIA Corporation.  All rights reserved.
#
TARGET_FACTORY_RAMDISK_OUT := $(PRODUCT_OUT)/factory_ramdisk
BUILD_FACTORY_DEFAULT_PROPERTIES := true
DIAG_KERNEL_CMDLINE := buildvariant=userdebug
ifndef DIAG_KERNEL_CONFIG_OVERRIDES
NV_DIAG_KERNEL_CONFIG := \
		--enable DEVMEM \
		--enable DEBUG_FS
else
NV_DIAG_KERNEL_CONFIG := $(DIAG_KERNEL_CONFIG_OVERRIDES)
endif

#========================================================
_factory_product_var_list := \
PRODUCT_FACTORY_RAMDISK_MODULES \
PRODUCT_FACTORY_KERNEL_MODULES \

INTERNAL_PRODUCT := $(call resolve-short-product-name, $(TARGET_PRODUCT))
$(foreach v, $(_factory_product_var_list), $(if $($(v)),\
    $(eval PRODUCTS.$(INTERNAL_PRODUCT).$(v) += $(sort $($(v))))))

ifeq (,$(ONE_SHOT_MAKEFILE))
ifneq ($(TARGET_BUILD_PDK),true)
  TARGET_BUILD_FACTORY=true
endif
ifeq ($(TARGET_BUILD_FACTORY),true)

# PRODUCT_FACTORY_RAMDISK_MODULES consists of "<module_name>:<install_path>[:<install_path>...]" tuples.
# <install_path> is relative to TARGET_FACTORY_RAMDISK_OUT.
# We can have multiple <install_path>s because multiple modules may have the same name.
# For example:
# PRODUCT_FACTORY_RAMDISK_MODULES := \
#     toolbox:system/bin/toolbox adbd:sbin/adbd adb:system/bin/adb
factory_ramdisk_modules := $(strip $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_FACTORY_RAMDISK_MODULES))

ifneq (,$(factory_ramdisk_modules))
# A module name may end up in multiple modules (so multiple built files)
# with the same name.
# This function selects the module built file based on the install path.
# $(1): the dest install path
# $(2): the module built files
define install-one-factory-ramdisk-module
$(eval _iofrm_suffix := $(suffix $(1))) \
$(if $(_iofrm_suffix), \
    $(eval _iofrm_pattern := %$(_iofrm_suffix)), \
    $(eval _iofrm_pattern := %$(notdir $(1)))) \
$(eval _iofrm_src := $(filter $(_iofrm_pattern),$(2))) \
$(if $(filter 1,$(words $(_iofrm_src))), \
    $(eval _fulldest := $(TARGET_FACTORY_RAMDISK_OUT)/$(1)) \
    $(eval $(call copy-one-file,$(_iofrm_src),$(_fulldest))) \
    $(eval INTERNAL_FACTORY_RAMDISK_EXTRA_MODULES_FILES += $(_fulldest)), \
    $(warning Warning: Cannot find built file in "$(2)" for "$(1)") \
    )
endef

INTERNAL_FACTORY_RAMDISK_EXTRA_MODULES_FILES :=
$(foreach m, $(factory_ramdisk_modules), \
    $(eval _fr_m_tuple := $(subst :, ,$(m))) \
    $(eval _fr_m_name := $(word 1,$(_fr_m_tuple))) \
    $(eval _fr_dests := $(wordlist 2,999,$(_fr_m_tuple))) \
    $(eval _fr_m_built := $(filter $(PRODUCT_OUT)/%, $(ALL_MODULES.$(_fr_m_name).BUILT))) \
    $(foreach d,$(_fr_dests),$(call install-one-factory-ramdisk-module,$(d),$(_fr_m_built))) \
    )
else
    $(info Factory: Ramdisk module not defined)
endif #ifneq (,$(factory_ramdisk_modules))

#========================================================
# Build diag kernel and kernel module
# Diag usually shares kernel with a normal one in each build type
# but diag will build its own kernel in user-release mode to enable debug options such as debugfs
TARGET_ARCH_KERNEL ?= $(TARGET_ARCH)
INSTALLED_DIAG_KERNEL_TARGET := $(INSTALLED_KERNEL_TARGET)
NV_DIAG_BUILD_KERNEL_FOLDER_NAME := $(notdir $(patsubst %/,%,$(KERNEL_PATH)))
NV_DIAG_BUILD_KERNEL_SOURCE      := $(CURDIR)/kernel/$(NV_DIAG_BUILD_KERNEL_FOLDER_NAME)

ifneq ($(filter /%, $(TARGET_OUT_INTERMEDIATES)),)
NV_DIAG_KERNEL_INTERMEDIATES_DIR := $(TARGET_OUT_INTERMEDIATES)/DIAG_KERNEL/$(NV_DIAG_BUILD_KERNEL_FOLDER_NAME)
NV_DIAG_KERNEL_DTB_DIR := $(TARGET_OUT_INTERMEDIATES)/DIAG_KERNEL/dtb
NV_DIAG_KERNEL_MODULES_TARGET_DIR := $(TARGET_OUT_INTERMEDIATES)/DIAG_KERNEL/lib
else
NV_DIAG_KERNEL_INTERMEDIATES_DIR := $(CURDIR)/$(TARGET_OUT_INTERMEDIATES)/DIAG_KERNEL/$(NV_DIAG_BUILD_KERNEL_FOLDER_NAME)
NV_DIAG_KERNEL_DTB_DIR := $(CURDIR)/$(TARGET_OUT_INTERMEDIATES)/DIAG_KERNEL/dtb
NV_DIAG_KERNEL_MODULES_TARGET_DIR := $(CURDIR)/$(TARGET_OUT_INTERMEDIATES)/DIAG_KERNEL/lib
endif

###############################################################################
#
# Toolchain paths defined in Makefile.kernel
#
NV_DIAG_BUILD_KERNEL_TOOLCHAIN_NAME=aarch64
NV_DIAG_BUILD_KERNEL_DTS_ROOT       := $(ANDROID_BUILD_TOP)/hardware/nvidia

# default to secure-os
NV_DIAG_BUILD_KERNEL_OPTIONS := tlk

ifeq ($(NVIDIA_KERNEL_COVERAGE_ENABLED),1)
    NV_DIAG_BUILD_KERNEL_OPTIONS += gcov
endif

ifneq ($(findstring 4.4,$(NV_DIAG_BUILD_KERNEL_FOLDER_NAME)),)
    NV_DIAG_BUILD_KERNEL_OPTIONS += 4.4
else ifneq ($(findstring 4.9,$(NV_DIAG_BUILD_KERNEL_FOLDER_NAME)),)
    NV_DIAG_BUILD_KERNEL_OPTIONS += 4.9
else ifneq ($(findstring shield,$(NV_DIAG_BUILD_KERNEL_FOLDER_NAME)),)
    NV_DIAG_BUILD_KERNEL_OPTIONS += shield
endif

ifeq ($(TARGET_BUILD_TYPE)-$(TARGET_BUILD_VARIANT),release-user)
    NV_DIAG_BUILD_KERNEL_OPTIONS += production
endif

ifeq ($(NV_BUILD_CONFIGURATION_IS_VERBOSE),1)
_kbuild_verbosity := 1
else
_kbuild_verbosity := 0
endif

ifeq ($(origin P4ROOT), undefined)
_toolchain_path               := $(CURDIR)/3rdparty/linaro/prebuilts/linux-x86/aarch64-linux-gnu-6.4.1-2017.08/bin/aarch64-linux-gnu-
else
_toolchain_path               := $(P4ROOT)/sw/mobile/tools/linux/linaro/gcc-linaro-6.4.1-2017.08-x86_64_aarch64-linux-gnu/bin/aarch64-linux-gnu-
endif

# aarch64
_toolchain_aarch64            := $(CURDIR)/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9/bin/aarch64-linux-android-
_toolchain_aarch64_gcc6       := $(_toolchain_path)
_toolchain_boot32_aarch64     := $(CURDIR)/prebuilts/gcc/linux-x86/arm/arm-eabi-4.8/bin/arm-eabi-
_toolchain_cflags_aarch64     := -mno-android
_toolchain_cflags_aarch64_gcc6     :=

# 32-bit toolchain for simulation boot image creation
NV_BUILD_KERNEL_BOOT32_TOOLCHAIN := $(_toolchain_boot32_$(NV_DIAG_BUILD_KERNEL_TOOLCHAIN_NAME))
ifeq ($(NV_BUILD_KERNEL_BOOT32_TOOLCHAIN),)
$(error unknown diag kernel 32bit toolchain name _toolchain_boot32_$(NV_DIAG_BUILD_KERNEL_TOOLCHAIN_NAME))
endif

# intentionally leave out embedded, which has yet to decide
ifneq ($(filter 4.9-aarch64 4.9-aarch64_l4t, $(findstring 4.9, $(NV_DIAG_BUILD_KERNEL_OPTIONS))-$(NV_DIAG_BUILD_KERNEL_TOOLCHAIN_NAME)),)
NV_DIAG_BUILD_KERNEL_TOOLCHAIN := $(_toolchain_$(NV_DIAG_BUILD_KERNEL_TOOLCHAIN_NAME)_gcc6)
NV_DIAG_BUILD_KERNEL_TOOLCHAIN_CFLAGS := $(_toolchain_cflags_$(NV_DIAG_BUILD_KERNEL_TOOLCHAIN_NAME)_gcc6)
else
NV_DIAG_BUILD_KERNEL_TOOLCHAIN := $(_toolchain_$(NV_DIAG_BUILD_KERNEL_TOOLCHAIN_NAME))
NV_DIAG_BUILD_KERNEL_TOOLCHAIN_CFLAGS := $(_toolchain_cflags_$(NV_DIAG_BUILD_KERNEL_TOOLCHAIN_NAME))
endif
ifeq ($(NV_DIAG_BUILD_KERNEL_TOOLCHAIN),)
$(error unknown diag kernel toolchain name _toolchain_$(NV_DIAG_BUILD_KERNEL_TOOLCHAIN_NAME))
endif

###############################################################################
ifndef DIAG_KERNEL_DEFCONFIG
    DEFCONFIG_PATH ?= $(KERNEL_PATH)/arch/$(TARGET_ARCH_KERNEL)/configs
    DIAG_KERNEL_DEFCONFIG =$(DEFCONFIG_PATH) $(TARGET_KERNEL_CONFIG)
endif

diag_kbuild = $(_kbuild_raw)
define _kbuild_raw
	$(MAKE) -C $(NV_DIAG_BUILD_KERNEL_SOURCE) -f Makefile ARCH=$(TARGET_ARCH_KERNEL) \
		LOCALVERSION="-tegra" CROSS_COMPILE=$(NV_DIAG_BUILD_KERNEL_TOOLCHAIN) KCFLAGS=$(NV_DIAG_BUILD_KERNEL_TOOLCHAIN_CFLAGS) \
		NV_BUILD_KERNEL_DTS_ROOT=$(NV_DIAG_BUILD_KERNEL_DTS_ROOT) \
		O=$(NV_DIAG_KERNEL_INTERMEDIATES_DIR) V=$(_kbuild_verbosity) CROSS32CC=$(NV_BUILD_KERNEL_BOOT32_TOOLCHAIN)gcc $(_kbuild_sparse)
endef

NV_DIAG_KERNEL_BUILD_DIRECTORY_LIST := \
	$(NV_DIAG_KERNEL_INTERMEDIATES_DIR) \
	$(NV_DIAG_KERNEL_DTB_DIR)           \
	$(NV_DIAG_KERNEL_MODULES_TARGET_DIR)

$(NV_DIAG_KERNEL_BUILD_DIRECTORY_LIST):
	$(hide) mkdir -p $@

# Build diag kernel if in user-release
ifeq ($(TARGET_BUILD_TYPE),release)
ifeq ($(TARGET_BUILD_VARIANT),user)
INSTALLED_DIAG_KERNEL_TARGET := $(NV_DIAG_KERNEL_INTERMEDIATES_DIR)/arch/$(TARGET_ARCH_KERNEL)/boot/zImage
$(INSTALLED_DIAG_KERNEL_TARGET): | $(NV_DIAG_KERNEL_INTERMEDIATES_DIR)
	@echo "Factory: Building diag kernel "
	$(diag_kbuild) DEFCONFIG_PATH=$(DIAG_KERNEL_DEFCONFIG)
	$(KERNEL_PATH)/scripts/config --file $(NV_DIAG_KERNEL_INTERMEDIATES_DIR)/.config $(NV_DIAG_KERNEL_CONFIG)
	$(diag_kbuild)

# Build diag kernel module if in user-release
FACTORY_KERNEL_MODULE_TARGET :=
factory_kernel_modules := $(strip $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_FACTORY_KERNEL_MODULES))
ifneq (,$(factory_kernel_modules))
FACTORY_KERNEL_MODULE_TARGET := $(TARGET_FACTORY_RAMDISK_OUT)/kmod
$(FACTORY_KERNEL_MODULE_TARGET): kmodules
	@echo "Factory: Building kernel modules"
	$(foreach m, $(factory_kernel_modules), \
		$(eval _fk_m_tuple := $(subst :, ,$(m))) \
		$(eval _fk_m_srcs += $(word 1,$(_fk_m_tuple))) \
		$(eval _fk_m_dests += $(PRODUCT_OUT)/$(word 2,$(_fk_m_tuple))) \
	)
	$(hide) for m in $(_fk_m_srcs) ; do $(diag_kbuild) M="$$m" ; done
	$(hide) for d in $(_fk_m_dests) ; do mkdir -p $$d; for f in `find $(_fk_m_srcs) -name "*.ko"` ; do cp -v "$$f" $$d ; done ; done
else
    $(info Factory: Kernel module not defined)
endif #ifneq (,$(factory_kernel_modules))
endif
endif

# Files may also be installed via PRODUCT_COPY_FILES, PRODUCT_PACKAGES etc.
INTERNAL_FACTORY_RAMDISK_FILES := $(filter $(TARGET_FACTORY_RAMDISK_OUT)/%, \
    $(ALL_DEFAULT_INSTALLED_MODULES))

# -----------------------------------------------------------------
# Build factory default.prop
ifeq ($(BUILD_FACTORY_DEFAULT_PROPERTIES),true)
$(info Factory: Building default.prop)
INSTALLED_FACTORY_DEFAULT_PROP_TARGET := $(TARGET_FACTORY_RAMDISK_OUT)/default.prop
INTERNAL_FACTORY_RAMDISK_FILES += $(INSTALLED_FACTORY_DEFAULT_PROP_TARGET)
FACTORY_DEFAULT_PROPERTIES := \
    $(call collapse-pairs, $(FACTORY_DEFAULT_PROPERTIES))
FACTORY_DEFAULT_PROPERTIES += \
    $(call collapse-pairs, $(ADDITIONAL_DEFAULT_PROPERTIES)) \
    $(call collapse-pairs, $(PRODUCT_DEFAULT_PROPERTY_OVERRIDES))

FACTORY_DEFAULT_PROPERTIES := $(call uniq-pairs-by-first-component, \
    $(FACTORY_DEFAULT_PROPERTIES),=)

$(INSTALLED_FACTORY_DEFAULT_PROP_TARGET):
	@echo Factory: Target buildinfo: $@
	@mkdir -p $(dir $@)
	$(hide) echo "#" > $@; \
	        echo "# FACTORY_DEFAULT_PROPERTIES" >> $@; \
	        echo "#" >> $@;
	$(hide) $(foreach line,$(FACTORY_DEFAULT_PROPERTIES), \
		echo "$(line)" >> $@;)
	$(hide) echo "#" >> $@; \
	        echo "# BOOTIMAGE_BUILD_PROPERTIES" >> $@; \
	        echo "#" >> $@;
	$(hide) echo ro.bootimage.build.date=`date`>>$@
	$(hide) echo ro.bootimage.build.date.utc=`date +%s`>>$@
	$(hide) echo ro.bootimage.build.fingerprint="$(BUILD_FINGERPRINT)">>$@
	$(hide) build/tools/post_process_props.py $@
endif #BUILD_FACTORY_DEFAULT_PROPERTIES

# These files are made by magic in build/core/Makefile so we need to explicitly include them
$(eval $(call copy-one-file,$(TARGET_OUT)/build.prop,$(TARGET_FACTORY_RAMDISK_OUT)/build.prop))
INTERNAL_FACTORY_RAMDISK_FILES += $(TARGET_FACTORY_RAMDISK_OUT)/build.prop

BUILT_FACTORY_RAMDISK_FS := $(PRODUCT_OUT)/factory_ramdisk.gz
BUILT_FACTORY_RAMDISK_TARGET := $(PRODUCT_OUT)/factory_ramdisk.img

ifdef FACTORY_RAMDISK_EXTRA_SYMLINKS
# FACTORY_RAMDISK_EXTRA_SYMLINKS is a list of <target>:<link_name>.
INTERNAL_FACTORY_RAMDISK_MODIFICATION += $(foreach s, $(FACTORY_RAMDISK_EXTRA_SYMLINKS),\
	$(eval p := $(subst :,$(space),$(s)))\
	mkdir -p $(dir $(TARGET_FACTORY_RAMDISK_OUT)/$(word 2,$(p))) ;\
	ln -sf $(word 1,$(p)) $(TARGET_FACTORY_RAMDISK_OUT)/$(word 2,$(p)) ;)
endif

ifdef BOARD_BUILD_SYSTEM_ROOT_IMAGE
INTERNAL_FACTORY_RAMDISK_DIRECTORYS += system_root
INTERNAL_FACTORY_RAMDISK_MODIFICATION += \
    rm -rf $(TARGET_FACTORY_RAMDISK_OUT)/system; \
    ln -sf /system_root/system $(TARGET_FACTORY_RAMDISK_OUT)/system;
endif

INSTALLED_FACTORY_RAMDISK_FS := $(BUILT_FACTORY_RAMDISK_FS)
$(INSTALLED_FACTORY_RAMDISK_FS) : $(FACTORY_KERNEL_MODULE_TARGET) $(MKBOOTFS) \
    $(INTERNAL_FACTORY_RAMDISK_EXTRA_MODULES_FILES) $(INTERNAL_FACTORY_RAMDISK_FILES) | $(MINIGZIP)
	$(foreach d, $(INTERNAL_FACTORY_RAMDISK_DIRECTORYS), $(shell mkdir -p $(TARGET_FACTORY_RAMDISK_OUT)/$(d)))
	$(shell $(INTERNAL_FACTORY_RAMDISK_MODIFICATION))
	$(call pretty,"Factory: Target ramdisk file system: $@")
	$(hide) $(MKBOOTFS) $(TARGET_FACTORY_RAMDISK_OUT) | $(MINIGZIP) > $@

INSTALLED_FACTORY_RAMDISK_TARGET := $(BUILT_FACTORY_RAMDISK_TARGET)
ifneq (,$(DIAG_KERNEL_CMDLINE))
  DIAG_KERNEL_CMDLINE_ARGS := --cmdline "$(DIAG_KERNEL_CMDLINE_ARGS)"
else
  DIAG_KERNEL_CMDLINE_ARGS :=
endif

# -----------------------------------------------------------------
# make factory_ramdisk.img and sign if need

ifneq ($(PLATFORM_IS_AFTER_N),1)
 ifndef BOARD_KERNEL_BASE
    BOARD_KERNEL_BASE:=10000000
 endif
 KERNEL_BASE_ARGS:= --base $(BOARD_KERNEL_BASE)
endif

ifeq (true,$(BOARD_AVB_ENABLE)) # TARGET_BOOTIMAGE_USE_EXT2 != true
$(INSTALLED_FACTORY_RAMDISK_TARGET): $(MKBOOTIMG) $(INSTALLED_DIAG_KERNEL_TARGET) $(INSTALLED_FACTORY_RAMDISK_FS) | $(AVBTOOL)
	$(call pretty,"Factory: Creating signed factory_ramdisk.img: $@")
	$(hide) $(MKBOOTIMG) --kernel $(INSTALLED_DIAG_KERNEL_TARGET) $(DIAG_KERNEL_CMDLINE_ARGS) $(KERNEL_BASE_ARGS) --ramdisk $(INSTALLED_FACTORY_RAMDISK_FS)  $(INTERNAL_MKBOOTIMG_VERSION_ARGS) $(BOARD_MKBOOTIMG_ARGS) --output $@
	$(hide) $(call assert-max-image-size,$@,$(BOARD_BOOTIMAGE_PARTITION_SIZE))
	$(hide) $(AVBTOOL) add_hash_footer \
	  --image $@ \
	  --partition_size $(BOARD_BOOTIMAGE_PARTITION_SIZE) \
	  --partition_name boot $(INTERNAL_AVB_SIGNING_ARGS) \
	  $(BOARD_AVB_BOOT_ADD_HASH_FOOTER_ARGS)
else ifeq (true,$(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_SUPPORTS_BOOT_SIGNER)) # BOARD_AVB_ENABLE != true
$(INSTALLED_FACTORY_RAMDISK_TARGET): $(MKBOOTIMG) $(INSTALLED_DIAG_KERNEL_TARGET) $(INSTALLED_FACTORY_RAMDISK_FS) $(BOOT_SIGNER)
	$(call pretty,"Factory: Creating signed factory_ramdisk.img: $@")
	$(hide) $(MKBOOTIMG) --kernel $(INSTALLED_DIAG_KERNEL_TARGET) --ramdisk $(INSTALLED_FACTORY_RAMDISK_FS) $(DIAG_KERNEL_CMDLINE_ARGS) $(KERNEL_BASE_ARGS) $(INTERNAL_MKBOOTIMG_VERSION_ARGS) $(BOARD_MKBOOTIMG_ARGS) --output $@
	$(BOOT_SIGNER) /boot $@ $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_VERITY_SIGNING_KEY).pk8 $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_VERITY_SIGNING_KEY).x509.pem $@
	$(hide) $(call assert-max-image-size,$@,$(BOARD_BOOTIMAGE_PARTITION_SIZE))
else
$(INSTALLED_FACTORY_RAMDISK_TARGET): $(MKBOOTIMG) $(INSTALLED_DIAG_KERNEL_TARGET) $(INSTALLED_FACTORY_RAMDISK_FS) $(BOOT_SIGNER)
	$(call pretty,"Factory: Creating factory_ramdisk.img: $@")
	$(hide) $(MKBOOTIMG) --kernel $(INSTALLED_DIAG_KERNEL_TARGET) --ramdisk $(INSTALLED_FACTORY_RAMDISK_FS) $(DIAG_KERNEL_CMDLINE_ARGS) $(KERNEL_BASE_ARGS) $(INTERNAL_MKBOOTIMG_VERSION_ARGS) $(BOARD_MKBOOTIMG_ARGS) --output $@
endif

# -----------------------------------------------------------------
# make factory_ota.zip and sign
ifeq (true,$(BUILD_FACTORY_OTA_PACKAGE))

name := $(TARGET_PRODUCT)-factory-ota-$(FILE_NAME_TAG)

FACTORY_OTA_PACKAGE_TARGET := $(PRODUCT_OUT)/$(FACTORY_OTA_PATH_OVERRIDE)/$(name).zip

$(FACTORY_OTA_PACKAGE_TARGET): KEY_CERT_PAIR := $(DEFAULT_KEY_CERT_PAIR)

$(FACTORY_OTA_PACKAGE_TARGET): $(INSTALLED_FACTORY_RAMDISK_TARGET) $(BUILT_TARGET_FILES_PACKAGE) \
		build/tools/releasetools/ota_from_target_files
	@echo "Package factory OTA: $@"
	$(hide) PATH=$(foreach p,$(INTERNAL_USERIMAGES_BINARY_PATHS),$(p):)$$PATH MKBOOTIMG=$(MKBOOTIMG) \
	   ./build/tools/releasetools/ota_from_target_files -v \
	   --block \
	   --factory \
	   --extracted_input_target_files $(patsubst %.zip,%,$(BUILT_TARGET_FILES_PACKAGE)) \
	   -p $(HOST_OUT) \
	   -k $(KEY_CERT_PAIR) \
	   $(BUILT_TARGET_FILES_PACKAGE) $@
endif #BUILD_FACTORY_OTA_PACKAGE

endif # TARGET_BUILD_FACTORY
endif # ONE_SHOT_MAKEFILE
