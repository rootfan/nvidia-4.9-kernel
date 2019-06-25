#
# Copyright (c) 2015, NVIDIA CORPORATION.  All rights reserved.
#

_nvidia_installed_files_host_bin_file    := $(PRODUCT_OUT)/nvidia_installed_files_host_bin.list
_nvidia_installed_files_product_out_file := $(PRODUCT_OUT)/nvidia_installed_files_product_out.list

# NOTE: TAB and empty line are important, so please do not remove them!
define _nvidia_installed_files_add_file
	echo "$(notdir $(1))" >> $@

endef

# installed NVIDIA host binaries
# incremental build support: we need to pick up changes in Android makefiles
.PHONY: $(_nvidia_installed_files_host_bin_file)
$(_nvidia_installed_files_host_bin_file):
	rm -f $@
	$(foreach m,$(ALL_NVIDIA_MODULES), \
		$(foreach i,$(ALL_MODULES.$(m).INSTALLED), \
			$(if $(filter $(i),$(modules_to_install)), \
				$(if $(filter $(HOST_OUT_EXECUTABLES)/,$(dir $(i))), \
					$(call _nvidia_installed_files_add_file,$(i))))))
	touch $@

dev: $(_nvidia_installed_files_host_bin_file)

# installed files with "LOCAL_MODULE_PATH := $(PRODUCT_OUT)"
#
# incremental build support: we need to pick up changes in Android makefiles
.PHONY: $(_nvidia_installed_files_product_out_file)
$(_nvidia_installed_files_product_out_file):
	rm -f $@
	$(foreach i,$(modules_to_install), \
		$(if $(filter $(PRODUCT_OUT)/,$(dir $(i))), \
			$(call _nvidia_installed_files_add_file,$(i))))
	touch $@

dev: $(_nvidia_installed_files_product_out_file)

_nvidia_installed_files_host_bin_file    :=
_nvidia_installed_files_product_out_file :=
