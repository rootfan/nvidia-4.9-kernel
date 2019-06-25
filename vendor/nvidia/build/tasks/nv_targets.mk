#
# Nvidia specific targets
#

.PHONY: dev nv-blob sim-image list-non-nv-modules nv-vbmetaimage device-manifest

dev: droidcore target-files-package factory_ramdisk nv-vbmetaimage

#
# bootloader blob target and macros
#

# macro: checks file existence and returns list of existing file
# $(1) list of file paths
define _dynamic_blob_dependencies
$(foreach f,$(1), $(eval \
 ifneq ($(wildcard $(f)),)
  _dep += $(f)
 endif))\
 $(_dep)
 $(eval _dep :=)
endef

# macro: construct command line for nvblob based on type of input file
# $(1) list of file paths
define _blob_command_line
$(foreach f,$(1), $(eval \
 ifneq ($(filter %microboot.bin,$(f)),)
  _cmd += $(f) NVC 1
  _cmd += $(f) RMB 1
 else ifneq ($(filter %nvtboot.bin,$(f)),)
  _cmd += $(f) NVC 1
 else ifneq ($(filter %bootloader.bin,$(f)),)
  _cmd += $(f) EBT 1
  _cmd += $(f) RBL 1
 else ifneq ($(filter %cboot.bin,$(f)),)
  _cmd += $(f) EBT 1
  _cmd += $(f) RBL 1
 else ifneq ($(filter %.dtb,$(f)),)
  _cmd += $(f) DTB 1
 else ifneq ($(filter %.bct,$(f)),)
  _cmd += $(f) BCT 1
 else ifneq ($(filter %bootsplash.bmp,$(f)),)
  _cmd += $(f) BMP 1
 else ifneq ($(filter %nvidia.bmp,$(f)),)
  _cmd += $(f) BMP 1
 else ifneq ($(filter %charged.bmp,$(f)),)
  _cmd += $(f) FBP 1
 else ifneq ($(filter %charging.bmp,$(f)),)
  _cmd += $(f) CHG 1
 else ifneq ($(filter %fullycharged.bmp,$(f)),)
  _cmd += $(f) FCG 1
 else ifneq ($(filter %lowbat.bmp,$(f)),)
  _cmd += $(f) LBP 1
 else ifneq ($(filter %mts_si,$(f)),)
  _cmd += $(f) MBP 1
  _cmd += $(f) RBP 1
 else ifneq ($(filter %mts_prod,$(f)),)
  _cmd += $(f) MBP 1
  _cmd += $(f) RBP 1
 else ifneq ($(filter %mts_slow_stable_prod,$(f)),)
  _cmd += $(f) MBP 1
  _cmd += $(f) RBP 1
 else ifneq ($(filter %mts_preboot_si,$(f)),)
  _cmd += $(f) MPB 1
  _cmd += $(f) RPB 1
 else ifneq ($(filter %mts_preboot_prod,$(f)),)
  _cmd += $(f) MPB 1
  _cmd += $(f) RPB 1
 else ifneq ($(filter %mts_preboot_slow_stable_prod,$(f)),)
  _cmd += $(f) MPB 1
  _cmd += $(f) RPB 1
 else ifneq ($(filter %xusb_sil_rel_fw,$(f)),)
  _cmd += $(f) DFI 1
 else ifneq ($(filter %tos.img,$(f)),)
  _cmd += $(f) TOS 1
 else ifneq ($(filter %nvtbootwb0.bin,$(f)),)
  _cmd += $(f) WB0 1
 else ifneq ($(filter %bootsplash_land.bmp,$(f)),)
  _cmd += $(f) RP4 1
 endif))\
 $(_cmd)
 $(eval _cmd :=)
endef

# These are additional files for which we generate blobs only if they exists
ifneq ($(filter t186,$(TARGET_TEGRA_VERSION)),)
_blob_deps := \
	$(HOST_OUT_EXECUTABLES)/tegraflash.py \
	$(HOST_OUT_EXECUTABLES)/part_table_ops.py \
	$(PRODUCT_OUT)/tnspec.py \
	$(PRODUCT_OUT)/tnspec.json \
	$(PRODUCT_OUT)/tnspec_t194.json

_blob_gen_path := $(TOP)/device/nvidia-t18x/t186/BUP/BUP_platform.sh
_blob_generator := $(HOST_OUT_EXECUTABLES)/BUP_generator.py

nv-blob: $(_blob_gen_path) $(_blob_generator) \
	$(call _dynamic_blob_dependencies, $(_blob_deps))
	$(hide) $<
ifeq ($(filter mystique_p tesseract_p,$(TARGET_PRODUCT)),)
	# skip building t194 blob for t186-only products
	$(hide) $< -t tnspec_t194.json
endif

else ifneq ($(filter t210,$(TARGET_TEGRA_VERSION)),)
_blob_deps := \
	$(HOST_OUT_EXECUTABLES)/tegraflash.py \
	$(PRODUCT_OUT)/cboot.bin \
	$(wildcard $(PRODUCT_OUT)/*.xml) \
	$(wildcard $(PRODUCT_OUT)/$(TARGET_KERNEL_DT_NAME)*.dtb) \
	$(wildcard $(PRODUCT_OUT)/$(TARGET_KERNEL_DT_NAME)*.cfg) \
	$(PRODUCT_OUT)/nvtboot_recovery.bin \
	$(PRODUCT_OUT)/bpmp.bin \
	$(PRODUCT_OUT)/nvtboot_cpu.bin \
	$(PRODUCT_OUT)/nvtboot.bin \
	$(PRODUCT_OUT)/warmboot.bin \
	$(PRODUCT_OUT)/tos.img \
	$(PRODUCT_OUT)/bmp.blob
_blob_gen_path := $(TOP)/device/nvidia/common/blob_generation.sh
_blob_generator := $(HOST_OUT_EXECUTABLES)/nvblob_v2

nv-blob: $(_blob_gen_path) $(_blob_generator) \
	$(call _dynamic_blob_dependencies, $(_blob_deps))
	$<

else
_blob_deps := \
      $(HOST_OUT_EXECUTABLES)/nvsignblob \
      $(PRODUCT_OUT)/microboot.bin \
      $(wildcard $(PRODUCT_OUT)/$(TARGET_KERNEL_DT_NAME)*.dtb) \
      $(wildcard $(PRODUCT_OUT)/*.bmp) \
      $(PRODUCT_OUT)/flash.bct \
      $(PRODUCT_OUT)/nvtboot.bin \
      $(PRODUCT_OUT)/bootloader.bin \
      $(PRODUCT_OUT)/cboot.bin \
      $(wildcard $(PRODUCT_OUT)/mts_*) \
      $(PRODUCT_OUT)/xusb_sil_rel_fw \
      $(PRODUCT_OUT)/tos.img \
      $(PRODUCT_OUT)/nvtbootwb0.bin
_blob_generator := $(HOST_OUT_EXECUTABLES)/nvblob

nv-blob: \
	$(_blob_generator) \
	$(TOP)/device/nvidia/common/security/signkey.pk8 \
	$(call _dynamic_blob_dependencies, $(_blob_deps))
	$(hide) python $< \
		 $(call _blob_command_line, $^)

endif

#
# Generate simulation images for supported board
#

ifeq ($(wildcard vendor/nvidia/tegra/core-private), vendor/nvidia/tegra/core-private)
ifeq ($(BOARD_SUPPORT_SIMULATION),true)
dev: sim-image

# no kernel is built with mp dev if modular kernel is enabled.
ifeq ($(filter kernel,$(BUILD_BRAIN_MODULAR_COMPONENTS)),)

# Re-use values from tasks/kernel.mk:
# - NV_BUILD_KERNEL_OPTIONS
# - TARGET_KERNEL_CONFIG
BOOT_WRAPPER_CMD_ARGS :=
ifneq ($(strip $(SHOW_COMMANDS)),)
    BOOT_WRAPPER_CMD_ARGS += NV_BUILD_CONFIGURATION_IS_VERBOSE=1
endif
BOOT_WRAPPER_CMD_ARGS += NV_BUILD_KERNEL_CONFIG_NAME=$(TARGET_KERNEL_CONFIG)
BOOT_WRAPPER_CMD_ARGS += NV_BUILD_KERNEL_OPTIONS="$(NV_BUILD_KERNEL_OPTIONS)"
BOOT_WRAPPER_CMD_ARGS += NV_BUILD_KERNEL64_SIM_DTS=$(SIM_KERNEL_DT_NAME).dts

# secure os
secure_os_image := $(PRODUCT_OUT)/trusty_sim_lk.bin
BOOT_WRAPPER_CMD_ARGS += NV_BUILD_KERNEL64_SECURE_OS=$(secure_os_image)
sim-image: $(secure_os_image)
secure_os_image :=

# secure monitor
secure_monitor_image := $(PRODUCT_OUT)/trusty_sim_atf.bin
BOOT_WRAPPER_CMD_ARGS += NV_BUILD_KERNEL64_EL3_MONITOR=$(secure_monitor_image)
sim-image: $(secure_monitor_image)
secure_monitor_image :=

ifneq ($(filter /%, $(TARGET_OUT_INTERMEDIATES)),)
sim-image: PRIVATE_INTERMEDIATES_DIR := $(TARGET_OUT_INTERMEDIATES)/KERNEL/$(notdir $(patsubst %/,%,$(KERNEL_PATH)))
else
sim-image: PRIVATE_INTERMEDIATES_DIR := $(CURDIR)/$(TARGET_OUT_INTERMEDIATES)/KERNEL/$(notdir $(patsubst %/,%,$(KERNEL_PATH)))
endif

ifeq ($(PLATFORM_IS_AFTER_N),1)
    sim_image_minimal := minimal_android_o
else
    sim_image_minimal := minimal
endif

sim-image: PRIVATE_BOOT_WRAPPER_CMD_ARGS := $(BOOT_WRAPPER_CMD_ARGS)
sim-image: droidcore $(BUILT_KERNEL_TARGET)
	device/nvidia/common/copy_simtools.sh
	python vendor/nvidia/tegra/simtools/ramdisk_gen/ramdisk_gen.py --modules=$(sim_image_minimal) --target_device=$(TARGET_DEVICE) --name=android_minimal_ramdisk.img
	@echo "Generating sdmmc image w/ minimal filesystem ..."
	$(MAKE) -C $(TOP) -f kernel-build/make/Makefile.kernel \
		NV_BUILD_KERNEL_ARCH_DIR=arm64 \
		NV_BUILD_KERNEL_TOOLCHAIN_NAME=aarch64 \
		NV_BUILD_KERNEL64_INITRD=$(PRODUCT_OUT)/android_minimal_ramdisk.img \
		NV_OUTDIR=$(PRIVATE_INTERMEDIATES_DIR) \
		$(PRIVATE_BOOT_WRAPPER_CMD_ARGS) build-qt

BOOT_WRAPPER_CMD_ARGS :=

else #  BUILD_BRAIN_MODULAR_COMPONENTS kernel
# required by sanity_pkg.sh
sim-image:
	device/nvidia/common/copy_simtools.sh
endif # BUILD_BRAIN_MODULAR_COMPONENTS

endif # BOARD_SUPPORT_SIMULATION true
endif # vendor/nvidia/tegra/core-private


# This macro lists all modules filtering those which
# 1. Are in a path which contains 'nvidia'
# 2. Have dependencies which are in a path which contains 'nvidia'
# TODO: This doesn't work well if a dependency have same name but different
# class. Eg. libexpat which is defined in multiple makefiles as host shared
# lib, shared lib and static lib
define list_nv_independent_modules
$(foreach _m,$(call module-names-for-tag-list,$(ALL_MODULE_TAGS)), \
    $(if $(findstring nvidia,$(ALL_MODULES.$(_m).PATH)), \
        $(info Skipping $(_m) location : $(ALL_MODULES.$(_m).PATH)), \
        $(if $(strip $(ALL_MODULES.$(_m).REQUIRED)), \
	    $(foreach _d,$(ALL_MODULES.$(_m).REQUIRED), \
	        $(if $(findstring nvidia,$(ALL_MODULES.$(_d).PATH)), \
	            $(info Skipping $(_m) location : $(ALL_MODULES.$(_m).PATH) dependency : $(_d) dependency location : $(ALL_MODULES.$(_d).PATH)), \
	            $(_m) \
	        ) \
	    ), \
	    $(_m) \
        ) \
    ) \
)
endef

# Generate NV specified vbmeta.img
ifeq ($(BOARD_AVB_ENABLE), true)
ifeq ($(PLATFORM_IS_AFTER_O_MR0),1)
nv-vbmetaimage: nv_avbtool
	$(TOP)/$(AVBTOOL) extract_public_key --key $(BOARD_AVB_KEY_PATH) --output $(PRODUCT_OUT)/testkey.avbpubkey
	$(TOP)/$(AVBTOOL) make_vbmeta_image \
	--set_hashtree_disabled_flag \
	--chain_partition boot:1:$(PRODUCT_OUT)/testkey.avbpubkey \
	--chain_partition system:2:$(PRODUCT_OUT)/testkey.avbpubkey \
	--chain_partition kernel-dtb:3:$(PRODUCT_OUT)/testkey.avbpubkey \
	--chain_partition vendor:4:$(PRODUCT_OUT)/testkey.avbpubkey \
	--algorithm $(BOARD_AVB_ALGORITHM) --key $(TOP)/$(BOARD_AVB_KEY_PATH) \
	--output $(PRODUCT_OUT)/nv_vbmeta.img
	rm -f $(PRODUCT_OUT)/testkey.avbpubkey
else
nv-vbmetaimage: nv_avbtool
	$(TOP)/$(AVBTOOL) extract_public_key --key $(BOARD_AVB_KEY_PATH) --output $(PRODUCT_OUT)/testkey.avbpubkey
	$(TOP)/$(AVBTOOL) make_vbmeta_image \
	--chain_partition boot:1:$(PRODUCT_OUT)/testkey.avbpubkey \
	--chain_partition system:2:$(PRODUCT_OUT)/testkey.avbpubkey \
	--chain_partition kernel-dtb:3:$(PRODUCT_OUT)/testkey.avbpubkey \
	--chain_partition vendor:4:$(PRODUCT_OUT)/testkey.avbpubkey \
	--algorithm $(BOARD_AVB_ALGORITHM) --key $(TOP)/$(BOARD_AVB_KEY_PATH) \
	--output $(PRODUCT_OUT)/nv_vbmeta.img
	rm -f $(PRODUCT_OUT)/testkey.avbpubkey
endif
else
nv-vbmetaimage:
	@echo "AVB is not enabled, skip gererating nv_vbmeta.img... "
endif

$(BUILT_VENDORIMAGE_TARGET): device-manifest

device-manifest:
	$(hide) mkdir -p $(TARGET_OUT_VENDOR); \
	echo -e '<manifest version="1.0" type="device">' > $(TARGET_OUT_VENDOR)/manifest.xml; \
	$(foreach m, $(PRODUCT_MANIFEST), cat $$TOP/$(m) >> $(TARGET_OUT_VENDOR)/manifest.xml;) \
	echo -e '</manifest>' >> $(TARGET_OUT_VENDOR)/manifest.xml

# List all nvidia independent modules as well as modules skipped with reason
list-non-nv-modules:
	@echo "Nvidia independent modules analysis:"
	@for m in $(call list_nv_independent_modules); do echo $$m; done | sort -u

# Clear local variable
_blob_deps :=
_blob_generator :=
_blob_gen_path :=
