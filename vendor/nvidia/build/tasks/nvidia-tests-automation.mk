ifneq ($(filter nvidia-tests-automation,$(MAKECMDGOALS)),)

_target_list_file := $(PRODUCT_OUT)/nvidia_tests/target.list
_target_list :=
_host_list_file := $(PRODUCT_OUT)/nvidia_tests/host.list
_host_list :=

define nvidia-test-automation-install-path
$(eval _binstalled := $(strip $(ALL_MODULES.$(1).BUILT_INSTALLED)))
$(eval _flist := $(strip $(ALL_NVIDIA_MODULES.$(1).INSTALLED_FILES)))
# Handle the case where module contains both real and fake targets.
$(foreach class,$(ALL_MODULES.$(1).CLASS),\
    $(if $(filter-out FAKE,$(class)),\
        $(eval _flist += $(firstword $(_binstalled)))\
    )\
    $(eval _binstalled := $(wordlist 2,$(words $(_binstalled)),$(_binstalled)))\
)

#Add target paths to right list
$(foreach part,$(_flist),\
    $(eval _dest := $(lastword $(subst :, ,$(part))))\
    $(if $(filter $(HOST_OUT)/%,$(_dest)),\
        $(eval _host_list += $(_dest))\
    ,$(if $(filter-out $(PRODUCT_OUT)/nvidia_tests/%,$(_dest)),\
        $(eval _target_list += $(_dest))\
    ,\
        $(error $(1) Should not install $(_dest) directly under nvidia_tests. Fix your Makefile!)\
    ))\
)
endef

_empty :=
define _rule_prefix

	$(_empty)
endef

define _dump-file-list
# for incremental build support
.PHONY: $($(1)_file)
$($(1)_file): $($(1)) |$(dir $($(1)_file))
	rm -f $$@
	$(foreach line,$(subst $(2),,$($(1))),\
		$(_rule_prefix)printf '%s\n' '$(line)' >> $$@)
	touch $$@
endef

$(foreach module,$(ALL_NVIDIA_TESTS), \
    $(eval $(call nvidia-test-automation-install-path,$(module))))

$(eval $(call _dump-file-list,_target_list,$(PRODUCT_OUT)/))
$(eval $(call _dump-file-list,_host_list,$(HOST_OUT)/))

nvidia-tests-automation: $(_host_list) $(_host_list_file) \
                         $(_target_list) $(_target_list_file)

# Nvidia sanity tests assume that tests and associated data are included in the
# OS images. The following dependencies make sure that target test files are
# installed before image files are created.
$(BUILT_SYSTEMIMAGE): $(filter $(TARGET_OUT)/%,$(_target_list))
ifdef BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE
$(BUILT_VENDORIMAGE_TARGET): $(filter $(TARGET_OUT_VENDOR)/%,$(_target_list))
endif
$(BUILT_USERDATAIMAGE_TARGET): $(filter $(TARGET_OUT_DATA)/%,$(_target_list))

$(sort $(dir $(_target_list_file) $(_host_list_file))):
	mkdir -p $@

_dump-file-list :=
_rule_prefix :=
nvidia-test-automation-install-path :=
_host_list :=
_host_list_file :=
_target_list :=
_target_list_file :=

endif
