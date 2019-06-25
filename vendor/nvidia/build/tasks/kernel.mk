#
# Linux kernel and loadable kernel modules
#

# We don't need kernel for standalone bootloader build
ifeq ($(BUILD_STANDALONE_BOOTLOADER), 1)
TARGET_NO_KERNEL := true
endif

# record defconfig name for build modularization
$(PRODUCT_OUT)/kernel-configuration-name.txt:
	$(hide) echo $(TARGET_KERNEL_CONFIG) >$@

# record SIM DTS name for build modularization
$(PRODUCT_OUT)/kernel-simdts-name.txt:
	$(hide) echo $(SIM_KERNEL_DT_NAME).dts >$@

# always provide these targets, at least as no-op target
.PHONY: build_kernel_tests kernel-tests

ifneq ($(filter kernel,$(BUILD_BRAIN_MODULAR_COMPONENTS)),)
# Provide dummy targets for system builder when modular kernel is enabled

# Provide a dummy kernel image
$(INSTALLED_KERNEL_TARGET): | $(PRODUCT_OUT)/kernel-simdts-name.txt
	$(hide) mkdir -p $(dir $@)
	$(hide) touch $@

else ifdef BUILD_BRAIN_MODULAR_NAME
# Nothing to do in user space module builders.
# The kernel module builder doesn't use the Android build system, so it doesn't
# need to be handled here.
else ifneq ($(TARGET_NO_KERNEL),true)

ifneq ($(NV_SKIP_KERNEL_BUILD),1)

ifneq ($(TOP),.)
$(error Kernel build assumes TOP == . i.e Android build has been started from TOP/Makefile )
endif

OS=$(shell uname)
ifeq ($(OS),Darwin)
    $(error Kernel build not supported on Darwin)
endif


# Android build is started from the $TOP/Makefile, therefore $(CURDIR)
# gives the absolute path to the TOP.
KERNEL_PATH ?= $(CURDIR)/kernel/kernel-4.4
NV_BUILD_KERNEL_FOLDER_NAME := $(notdir $(patsubst %/,%,$(KERNEL_PATH)))

# Special handling for ARM64 kernel (diff arch/ and built-in bootloader)
TARGET_ARCH_KERNEL ?= $(TARGET_ARCH)

# Always use absolute path for NV_KERNEL_INTERMEDIATES_DIR
# keep same directory structure between $(NV_KERNEL_INTERMEDIATES_DIR)/KERNEL/* and $(CURDIR)/kernel/*
ifneq ($(filter /%, $(TARGET_OUT_INTERMEDIATES)),)
NV_KERNEL_INTERMEDIATES_DIR := $(TARGET_OUT_INTERMEDIATES)/KERNEL/$(NV_BUILD_KERNEL_FOLDER_NAME)
else
NV_KERNEL_INTERMEDIATES_DIR := $(CURDIR)/$(TARGET_OUT_INTERMEDIATES)/KERNEL/$(NV_BUILD_KERNEL_FOLDER_NAME)
endif

ifeq ($(TARGET_ARCH_KERNEL),arm64)
ifeq ($(BOARD_SUPPORT_KERNEL_COMPRESS),gzip)
BUILT_KERNEL_TARGET := $(NV_KERNEL_INTERMEDIATES_DIR)/arch/$(TARGET_ARCH_KERNEL)/boot/zImage
else
BUILT_KERNEL_TARGET := $(NV_KERNEL_INTERMEDIATES_DIR)/arch/$(TARGET_ARCH_KERNEL)/boot/Image
endif
else
BUILT_KERNEL_TARGET := $(NV_KERNEL_INTERMEDIATES_DIR)/arch/$(TARGET_ARCH_KERNEL)/boot/zImage
endif

TARGET_KERNEL_CONFIG ?= tegra_android_defconfig
NV_BUILD_KERNEL_TOOLCHAIN_NAME := aarch64
NV_BUILD_KERNEL_TOOLCHAIN := $(CURDIR)/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9/bin/aarch64-linux-android-

ifneq ($(strip $(SHOW_COMMANDS)),)
    NV_BUILD_KERNEL_IS_VERBOSE=1
endif

ifneq ($(wildcard vendor/nvidia/tegra/core-private),)
    NV_BUILD_KERNEL_CUSTOMER_BUILD :=
    NV_BUILD_KERNEL_MAKEFILE_PATH  := $(TOP)
else
    NV_BUILD_KERNEL_CUSTOMER_BUILD := 1
    NV_BUILD_KERNEL_MAKEFILE_PATH  := $(TOP)/vendor/nvidia/tegra/prebuilt/$(REFERENCE_DEVICE)
endif

ifeq ($(TARGET_TEGRA_VERSION),t210)
    NV_BUILD_KERNEL_MODULES_ODM_LIST := $(TOP)/device/nvidia/platform/t210/lkm/odm.list
else
    NV_BUILD_KERNEL_MODULES_ODM_LIST := $(TOP)/device/nvidia-t18x/t186/lkm/odm.list
endif

# Always use absolute path for NV_KERNEL_MODULES_*_TARGET_DIR and
# NV_KERNEL_BIN_TARGET_DIR
ifneq ($(filter /%, $(TARGET_OUT_VENDOR)),)
NV_KERNEL_MODULES_TARGET_DIR := $(TARGET_OUT_VENDOR)/lib/modules
else
NV_KERNEL_MODULES_TARGET_DIR := $(CURDIR)/$(TARGET_OUT_VENDOR)/lib/modules
endif

#Fmac driver modules
NV_FMAC_KERNEL_DIR := $(CURDIR)/vendor/nvidia/tegra/3rdparty/cypress-fmac/backports-wireless
NV_FMAC_KERNEL_MODULES_TARGET_DIR := $(NV_KERNEL_MODULES_TARGET_DIR)

ifneq ($(filter /%, $(TARGET_OUT_ODM)),)
NV_KERNEL_MODULES_TARGET_DIR2 := $(TARGET_OUT_ODM)/lib/modules
else
NV_KERNEL_MODULES_TARGET_DIR2 := $(CURDIR)/$(TARGET_OUT_ODM)/lib/modules
endif

ifneq ($(filter /%, $(TARGET_OUT)),)
NV_KERNEL_BIN_TARGET_DIR     := $(TARGET_OUT)/bin
else
NV_KERNEL_BIN_TARGET_DIR     := $(CURDIR)/$(TARGET_OUT)/bin
endif

# default to secure-os
NV_BUILD_KERNEL_OPTIONS := tlk

ifeq ($(NVIDIA_KERNEL_COVERAGE_ENABLED),1)
    NV_BUILD_KERNEL_OPTIONS += gcov
endif

ifneq ($(findstring 4.4,$(NV_BUILD_KERNEL_FOLDER_NAME)),)
    NV_BUILD_KERNEL_OPTIONS += 4.4
else ifneq ($(findstring 4.9,$(NV_BUILD_KERNEL_FOLDER_NAME)),)
    NV_BUILD_KERNEL_OPTIONS += 4.9
else ifneq ($(findstring 4.14,$(NV_BUILD_KERNEL_FOLDER_NAME)),)
    NV_BUILD_KERNEL_OPTIONS += 4.14
else ifneq ($(findstring shield,$(NV_BUILD_KERNEL_FOLDER_NAME)),)
    NV_BUILD_KERNEL_OPTIONS += shield
endif

ifeq ($(TARGET_BUILD_TYPE)-$(TARGET_BUILD_VARIANT),release-user)
    NV_BUILD_KERNEL_OPTIONS += production
endif

# check if kernel coverity check is enabled, enable Coverity build if
# NV_KERNEL_COVERITY_ENABLED is set to 1.
NV_BUILD_KERNEL_COVERITY_DIR :=
NV_BUILD_KERNEL_COVERITY_CONFIG :=

ifeq ($(NV_KERNEL_COVERITY_ENABLED),1)
NV_BUILD_KERNEL_COVERITY_DIR := $(NV_KERNEL_INTERMEDIATES_DIR)/coverity
NV_BUILD_KERNEL_COVERITY_CONFIG := $(NV_BUILD_KERNEL_COVERITY_DIR)/configs/coverity_config.xml
endif

# ALWAYS prefix these macros with "+" to correctly enable parallel building!
define kernel-make
	$(MAKE) -C $(TOP) -f $(PRIVATE_MAKEFILE_PATH)/kernel-build/make/Makefile.kernel     \
		NV_OUTDIR=$(PRIVATE_INTERMEDIATES_DIR)                                      \
		NV_BUILD_CONFIGURATION_IS_VERBOSE=$(PRIVATE_IS_VERBOSE)                     \
		NV_BUILD_KERNEL_ARCH_DIR=$(PRIVATE_ARCH_KERNEL)                             \
		NV_BUILD_KERNEL_CONFIG_NAME=$(PRIVATE_KERNEL_CONFIG_NAME)                   \
		NV_BUILD_KERNEL_OPTIONS="$(PRIVATE_KERNEL_OPTIONS)"                         \
		NV_BUILD_KERNEL_DTBS_INSTALL=$(PRIVATE_DTBS_INSTALL)                        \
		NV_BUILD_KERNEL_MODULES_INSTALL=$(PRIVATE_MODULES_INSTALL)                  \
		NV_BUILD_KERNEL_TOOLCHAIN_NAME=$(PRIVATE_TOOLCHAIN_NAME)                    \
		NV_CUSTOMER_BUILD=$(PRIVATE_CUSTOMER_BUILD)
endef

define fmac-kernel-make
	$(MAKE) -C $(NV_FMAC_KERNEL_DIR) \
		KLIB=$(PRIVATE_INTERMEDIATES_DIR) \
		KLIB_BUILD=$(PRIVATE_INTERMEDIATES_DIR) \
		defconfig-brcmfmac
	$(MAKE) -C $(NV_FMAC_KERNEL_DIR) \
		ARCH=$(TARGET_ARCH_KERNEL) \
		CROSS_COMPILE=$(NV_BUILD_KERNEL_TOOLCHAIN) \
		KLIB=$(PRIVATE_INTERMEDIATES_DIR) \
		KLIB_BUILD=$(PRIVATE_INTERMEDIATES_DIR) \
                modules \
		$(if $(SHOW_COMMANDS),V=1)
endef

# Set private variables required by kernel make targets
_kernel_make_targets := $(BUILT_KERNEL_TARGET) kmodules installed_dtbs build_kernel_tests build_tegrawatch
$(_kernel_make_targets): PRIVATE_ARCH_KERNEL        := $(TARGET_ARCH_KERNEL)
$(_kernel_make_targets): PRIVATE_BIN_TARGET_DIR     := $(NV_KERNEL_BIN_TARGET_DIR)
$(_kernel_make_targets): PRIVATE_CUSTOMER_BUILD     := $(NV_BUILD_KERNEL_CUSTOMER_BUILD)
$(_kernel_make_targets): PRIVATE_DTBS_INSTALL       := $(PRODUCT_OUT)
$(_kernel_make_targets): PRIVATE_INTERMEDIATES_DIR  := $(NV_KERNEL_INTERMEDIATES_DIR)
$(_kernel_make_targets): PRIVATE_IS_VERBOSE         := $(NV_BUILD_KERNEL_IS_VERBOSE)
$(_kernel_make_targets): PRIVATE_KERNEL_CONFIG_NAME := $(TARGET_KERNEL_CONFIG)
$(_kernel_make_targets): PRIVATE_KERNEL_OPTIONS     := $(NV_BUILD_KERNEL_OPTIONS)
$(_kernel_make_targets): PRIVATE_MAKEFILE_PATH      := $(NV_BUILD_KERNEL_MAKEFILE_PATH)
$(_kernel_make_targets): PRIVATE_MODULES_INSTALL    := $(NV_KERNEL_INTERMEDIATES_DIR)
$(_kernel_make_targets): PRIVATE_MODULES_TARGET_DIR := $(NV_KERNEL_MODULES_TARGET_DIR)
$(_kernel_make_targets): PRIVATE_MODULES_TARGET_DIR2:= $(NV_KERNEL_MODULES_TARGET_DIR2)
$(_kernel_make_targets): PRIVATE_TOOLCHAIN_NAME     := $(NV_BUILD_KERNEL_TOOLCHAIN_NAME)
ifneq ($(NV_BUILD_KERNEL_COVERITY_CONFIG),)
$(_kernel_make_targets): PRIVATE_COVERITY_WRAPPER   := cov-build --config $(NV_BUILD_KERNEL_COVERITY_CONFIG) \
						       --dir $(NV_BUILD_KERNEL_COVERITY_DIR)/emit
endif

_kernel_make_targets :=

.PHONY: $(NV_BUILD_KERNEL_COVERITY_CONFIG)
ifneq ($(NV_BUILD_KERNEL_COVERITY_CONFIG),)
$(NV_BUILD_KERNEL_COVERITY_CONFIG): | $(NV_BUILD_KERNEL_COVERITY_DIR)
	for toolchain in arm-cortex_a15-linux-gnueabi-gcc arm-cortex_a15-linux-gnueabi-g++ \
		arm-none-eabi-gcc arm-none-eabi-ar arm-none-eabi-g++ arm-eabi-gcc \
		aarch64-linux-android-gcc armv7a-hardfloat-linux-gnueabi Linux-ARMv7-gnueabihf \
		aarch64-unknown-linux-gnu-gcc aarch64-gnu-linux-gcc; do \
		cov-configure --config $@  --verbose 0 --comptype gcc --compiler $$toolchain --template; \
	done
endif

# build kernel (z)Image, dtbs and modules including kernel_space_tests modules
.PHONY: $(BUILT_KERNEL_TARGET)
$(BUILT_KERNEL_TARGET): $(NV_BUILD_KERNEL_COVERITY_CONFIG) | $(NV_KERNEL_INTERMEDIATES_DIR)
	@echo "Kernel build"
	+$(PRIVATE_COVERITY_WRAPPER) $(kernel-make) build
	@echo "Fmac driver build"
	@echo $(PRIVATE_INTERMEDIATES_DIR)
	+$(fmac-kernel-make)

# This will add all kernel modules we build for inclusion the system
# image - no blessing takes place.
.PHONY: kmodules
kmodules: $(BUILT_KERNEL_TARGET) | $(NV_KERNEL_MODULES_TARGET_DIR) | $(NV_FMAC_KERNEL_MODULES_TARGET_DIR)
	@echo "Kernel modules install"
	find $(PRIVATE_INTERMEDIATES_DIR)/..                     \
           ! -path "*kernel_space_tests*" ! -path "*tegrawatch*" \
           -name "*.ko" |                                        \
               xargs cp -uv -t $(PRIVATE_MODULES_TARGET_DIR)
	find $(PRIVATE_MODULES_TARGET_DIR) -name "*.ko"          \
           -exec $(NV_BUILD_KERNEL_TOOLCHAIN)strip --strip-debug {} ';'
	@echo "Fmac driver install"
	 mv $(NV_FMAC_KERNEL_DIR)/net/wireless/cfg80211.ko \
		$(NV_FMAC_KERNEL_MODULES_TARGET_DIR)/cy_cfg80211.ko
	find $(NV_FMAC_KERNEL_DIR) -name "*.ko" -print0 | xargs -0 -IX cp -v X $(NV_FMAC_KERNEL_MODULES_TARGET_DIR)
	mkdir -p $(PRIVATE_MODULES_TARGET_DIR2)
	for file in `cat $(NV_BUILD_KERNEL_MODULES_ODM_LIST)`; do \
		mv $(PRIVATE_MODULES_TARGET_DIR)/$$file \
			$(PRIVATE_MODULES_TARGET_DIR2) | true; \
	done

# Set dependencies to vendorimage and odmimages build
$(INSTALLED_VENDORIMAGE_TARGET): kmodules
$(INSTALLED_ODMIMAGE_TARGET): kmodules

# copy dtbs to $(PRODUCT_OUT). kbuild dtbs_install is not defined for arch64
# and old kernel version so better to do it manually.
# if verified boot is enabled, need to sign the dtb before copy
.PHONY: installed_dtbs
ifeq ($(TARGET_TEGRA_VERSION),t210)
    TARGET_KERNEL_DTBS := -name tegra210*.dtb
else ifeq ($(TARGET_TEGRA_VERSION),t186)
    TARGET_KERNEL_DTBS := ! -name *-bpmp-*.dtb -name tegra186*.dtb
    EXTRA_KERNEL_DTBS := -o ! -name *-bpmp-*.dtb -name tegra194*.dtb
else ifeq ($(TARGET_TEGRA_VERSION),t194)
    TARGET_KERNEL_DTBS := ! -name *-bpmp-* -name tegra194*.dtb
else
    $(error Unknown TARGET_KERNEL_DTBS, please add corresponding kernel DTBs.)
endif
ifndef PLATFORM_IS_AFTER_N
ifeq ($(BOARD_SUPPORT_VERIFIED_BOOT),true)
installed_dtbs: $(BOOT_SIGNER)
installed_dtbs: $(TOP)/build/target/product/security/verity.pk8
installed_dtbs: $(TOP)/build/target/product/security/verity.x509.pem
endif
installed_dtbs: $(BUILT_KERNEL_TARGET) | $(NV_KERNEL_INTERMEDIATES_DIR)
	@echo "Kernel dtbs install"
ifeq ($(BOARD_SUPPORT_VERIFIED_BOOT),true)
	find $(PRIVATE_INTERMEDIATES_DIR)/arch/$(PRIVATE_ARCH_KERNEL)/boot/dts \
		-maxdepth 1 \
		\( -name "*.dtb" -o -name "*.dtbo" \) \
		-printf "%f\n" | \
		xargs -I {dtb} $(BOOT_SIGNER) \
			/boot \
			$(PRIVATE_INTERMEDIATES_DIR)/arch/$(PRIVATE_ARCH_KERNEL)/boot/dts/{dtb} \
			$(filter %.pk8, $^) \
			$(filter %.x509.pem, $^) \
			$(PRIVATE_DTBS_INSTALL)/{dtb}
else
	find $(PRIVATE_INTERMEDIATES_DIR)/arch/$(PRIVATE_ARCH_KERNEL)/boot/dts \
		\( -name "*.dtb" -o -name "*.dtbo" \) | xargs cp -uv -t $(PRIVATE_DTBS_INSTALL)
endif
else
ifeq ($(BOARD_AVB_ENABLE), true)
installed_dtbs: nv_avbtool
endif
installed_dtbs: $(BUILT_KERNEL_TARGET) | $(NV_KERNEL_INTERMEDIATES_DIR)
	@echo "Kernel dtbs install"
	find $(PRIVATE_INTERMEDIATES_DIR)/arch/$(PRIVATE_ARCH_KERNEL)/boot/dts \
		\( -name "*.dtb" -o -name "*.dtbo" \) | xargs cp -uv -t $(PRIVATE_DTBS_INSTALL)
ifeq ($(BOARD_AVB_ENABLE), true)
	# Build .dtb.avb_signed file for kernel-dtb
	mkdir -p $(PRIVATE_DTBS_INSTALL)/dtb_signed
	find $(PRIVATE_DTBS_INSTALL) \
		-maxdepth 1 \
		$(TARGET_KERNEL_DTBS) \
		$(EXTRA_KERNEL_DTBS) \
		| xargs -I {} cp -uv {} $(PRIVATE_DTBS_INSTALL)/dtb_signed
	ls $(PRIVATE_DTBS_INSTALL)/dtb_signed | xargs -I {dtb} $(TOP)/$(AVBTOOL) add_hash_footer \
		--image  $(PRIVATE_DTBS_INSTALL)/dtb_signed/{dtb} \
		--partition_size $(BOARD_DTB_PARTITION_SIZE) \
		--partition_name kernel-dtb \
		--algorithm $(BOARD_AVB_ALGORITHM) \
		--key $(TOP)/$(BOARD_AVB_KEY_PATH)
	ls $(PRIVATE_DTBS_INSTALL)/dtb_signed | \
		xargs -I {dtb} mv -f $(PRIVATE_DTBS_INSTALL)/dtb_signed/{dtb} $(PRIVATE_DTBS_INSTALL)/{dtb}.avb_signed
	rm -rf $(PRIVATE_DTBS_INSTALL)/dtb_signed
else
	find $(PRIVATE_DTBS_INSTALL) \
		-maxdepth 1 \
		! -name "*-bpmp-*" -name $(TARGET_KERNEL_DTBS) | \
		xargs -I {dtb} cp -uv {dtb} {dtb}.avb_signed
endif
endif

# At this stage, BUILT_SYSTEMIMAGE in $TOP/build/core/Makefile has not
# yet been defined, so we cannot rely on it.
_systemimage_intermediates_kmodules := \
    $(call intermediates-dir-for,PACKAGING,systemimage)
BUILT_SYSTEMIMAGE_KMODULES := $(_systemimage_intermediates_kmodules)/system.img
NV_INSTALLED_SYSTEMIMAGE := $(PRODUCT_OUT)/system.img

# When kernel tests are built, we also want to update the system
# image, but in general case we do not want to build kernel tests
# always.
ifneq ($(findstring kernel-tests,$(MAKECMDGOALS)),)
kernel-tests: build_kernel_tests $(NV_INSTALLED_SYSTEMIMAGE) FORCE

# For parallel builds. Systemimage can only be built after kernel
# tests have been built.
$(BUILT_SYSTEMIMAGE_KMODULES): build_kernel_tests
endif

.PHONY: build_kernel_tests
build_kernel_tests: $(BUILT_KERNEL_TARGET) | $(NV_KERNEL_MODULES_TARGET_DIR) $(NV_KERNEL_BIN_TARGET_DIR) build_tegrawatch
	@echo "Kernel space tests build"
	find $(PRIVATE_INTERMEDIATES_DIR)/kernel_space_tests -name "*.ko" | \
		xargs cp -uv -t $(PRIVATE_MODULES_TARGET_DIR)
	mkdir -p $(PRIVATE_MODULES_TARGET_DIR2)
	for file in `cat $(NV_BUILD_KERNEL_MODULES_ODM_LIST)`; do \
		mv $(PRIVATE_MODULES_TARGET_DIR)/$$file \
			$(PRIVATE_MODULES_TARGET_DIR2) | true; \
	done
	find $(TOP)/vendor/nvidia/tegra/tests-kernel/linux/kernel_space_tests -name "*.sh" | \
		xargs cp -uv -t $(PRIVATE_BIN_TARGET_DIR)

.PHONY: build_tegrawatch
build_tegrawatch: $(BUILT_KERNEL_TARGET) | $(NV_KERNEL_MODULES_TARGET_DIR)
	@echo "Build kernel space build_tegrawatch start"
	find $(PRIVATE_INTERMEDIATES_DIR)/tegrawatch -name "*.ko" | \
		xargs cp -uv -t $(PRIVATE_MODULES_TARGET_DIR)
	mkdir -p $(PRIVATE_MODULES_TARGET_DIR2)
	for file in `cat $(NV_BUILD_KERNEL_MODULES_ODM_LIST)`; do \
		mv $(PRIVATE_MODULES_TARGET_DIR)/$$file \
			$(PRIVATE_MODULES_TARGET_DIR2) | true; \
	done
	@echo "Build kernel space build_tegrawatch done"

# Unless we hardcode the list of kernel modules, we cannot create
# a proper dependency from systemimage to the kernel modules.
# If we decide to hardcode later on, BUILD_PREBUILT (or maybe
# PRODUCT_COPY_FILES) can be used for including the modules in the image.
# For now, let's rely on an explicit dependency.
$(BUILT_SYSTEMIMAGE_KMODULES): kmodules

# Following dependency is already defined in $TOP/build/core/Makefile,
# but for the sake of clarity let's re-state it here. This dependency
# causes following dependencies to be indirectly defined:
#   $(NV_INSTALLED_SYSTEMIMAGE): kmodules $(BUILT_KERNEL_TARGET)
# which will prevent too early creation of systemimage.
$(NV_INSTALLED_SYSTEMIMAGE): $(BUILT_SYSTEMIMAGE_KMODULES)

# $(INSTALLED_KERNEL_TARGET) is defined in
# $(TOP)/build/target/board/Android.mk

ifeq ($(BOARD_SUPPORT_KERNEL_COMPRESS),lz4)
# replace kernel image with lz4 compressed kernel image
NVIDIA_KBUILD_TARGET := $(NV_KERNEL_INTERMEDIATES_DIR)/arch/$(TARGET_ARCH_KERNEL)/boot/zImage.lz4
$(NVIDIA_KBUILD_TARGET): $(BUILT_KERNEL_TARGET) | $(NVIDIA_LZ4C)
	@echo "NVIDIA_LZ4C make $@"
	$(hide)$(NVIDIA_LZ4C) -c1 -l -f $< $@
else
# default kernel
NVIDIA_KBUILD_TARGET := $(BUILT_KERNEL_TARGET)
endif

$(INSTALLED_KERNEL_TARGET): | $(PRODUCT_OUT)/kernel-configuration-name.txt
$(INSTALLED_KERNEL_TARGET): | $(PRODUCT_OUT)/kernel-simdts-name.txt
$(INSTALLED_KERNEL_TARGET): $(NVIDIA_KBUILD_TARGET) installed_dtbs FORCE | $(ACP)
	$(copy-file-to-target)

# Kernel build also includes some drivers as kernel modules which are
# packaged inside system image. Therefore, for incremental builds,
# dependency from kernel to installed system image must be introduced,
# so that recompilation of kernel automatically updates also the
# drivers in system image to be flashed to the device.
.PHONY: kernel
kernel: $(INSTALLED_KERNEL_TARGET) kmodules $(NV_INSTALLED_SYSTEMIMAGE)

NV_KERNEL_BUILD_DIRECTORY_LIST := \
	$(NV_KERNEL_INTERMEDIATES_DIR) \
	$(NV_KERNEL_MODULES_TARGET_DIR) \
	$(NV_KERNEL_MODULES_TARGET_DIR2) \
	$(NV_KERNEL_BIN_TARGET_DIR) \
	$(NV_BUILD_KERNEL_COVERITY_DIR)

$(NV_KERNEL_BUILD_DIRECTORY_LIST):
	$(hide) mkdir -p $@


# clear internal variables
NV_BUILD_KERNEL_COVERITY_CONFIG :=
NV_BUILD_KERNEL_COVERITY_DIR    :=
NV_BUILD_KERNEL_CUSTOMER_BUILD :=
NV_BUILD_KERNEL_FOLDER_NAME    :=
NV_BUILD_KERNEL_IS_VERBOSE     :=
NV_BUILD_KERNEL_MAKEFILE_PATH  :=
NV_BUILD_KERNEL_TOOLCHAIN_NAME :=
NV_KERNEL_INTERMEDIATES_DIR    :=
NV_KERNEL_MODULES_TARGET_DIR   :=
NV_KERNEL_MODULES_TARGET_DIR2  :=
NV_KERNEL_BIN_TARGET_DIR       :=

endif

endif
