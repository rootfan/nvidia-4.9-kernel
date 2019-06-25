# List of module names
NV_MODULARIZED_COMPONENTS :=

# Set list only when userspace modularization information is available
ifneq ($(wildcard $(TEGRA_TOP)/modular-config/userspace/configs),)
include $(TEGRA_TOP)/modular-config/userspace/configs/drivers.mk
include $(TEGRA_TOP)/modular-config/userspace/configs/tests.mk
endif

# Module specific configuration in NV_MODULARIZED.$(mod).PATHS
include \
	$(addsuffix /Makefile.config, \
	$(addprefix $(TEGRA_TOP)/modular-config/userspace/configs/, \
	$(NV_MODULARIZED_COMPONENTS)))

# Ignore tmake specific module variables
NV_COMPONENTS   :=
NV_REPOSITORIES :=

# Get the build module name for the current makefile.
# Will return an empty string if the makefile is not assigned to a build module.
define nvidia_get_build_modularization_name
$(strip \
  $(eval _nv_build_modularization_name := \
    $(strip \
      $(foreach mod,$(NV_MODULARIZED_COMPONENTS), \
        $(foreach path,$(NV_MODULARIZED.$(mod).PATHS), \
          $(if $(filter $(path)/%,$(LOCAL_MODULE_MAKEFILE)),$(mod)))))) \
  $(if $(filter 0,$(words $(_nv_build_modularization_name))), \
    $(eval _nv_build_modularization_name := ), \
    $(if $(filter-out 1,$(words $(_nv_build_modularization_name))), \
      $(error $(LOCAL_MODULE_MAKEFILE): Multiple build modules detected))) \
  $(_nv_build_modularization_name))
endef


# Hook called from build/core/base_rules.mk
# Can only contain optional code (ie. error checks).
define nvidia-build-modularization-base-rules-hook
  # Avoid double inclusion of build modularization base in module components
  $(if $(NVIDIA_BUILD_MODULARIZATION_NAME),,$(eval include $(NVIDIA_BUILD_MODULARIZATION_BASE)))

  # Check that we're only using templates that support modular builds in
  # modularized components.
  $(if $(NVIDIA_BUILD_MODULARIZATION_NAME), \
    $(if $(filter true,$(NVIDIA_TEMPLATE_SUPPORTS_BUILD_MODULARIZATION)), \
      , \
      $(error $(LOCAL_MODULE_MAKEFILE): Part of build module $(NVIDIA_BUILD_MODULARIZATION_NAME), must use modularization-aware NVIDIA template)))

  # Non modularized dependencies of modular components must also use templates
  # that support modular builds.
  # Cause a build failure when this condition is not met by defining an invalid
  # dependency.
  # We only apply this check under TEGRA_TOP, as we currently need to build
  # various non-modularized Google components in modular builds (bionic etc.)
  $(if $(filter 1,$(NVIDIA_BUILD_MODULARIZATION_IS_STUBBED)), \
    $(if $(filter true,$(NVIDIA_TEMPLATE_SUPPORTS_BUILD_MODULARIZATION)), \
      , \
      $(if $(filter $(TEGRA_TOP)/%,$(abspath $(TOP)/$(LOCAL_MODULE_MAKEFILE))), \
        $(eval LOCAL_ADDITIONAL_DEPENDENCIES = \
          "nvidia_dependency_of_modular_component_must_use_modularization_aware_template"))))
endef


# Call this in stub templates, to reset all local variables except those referenced
# in NVIDIA_BUILD_MODULARIZATION_STUB_NEEDS_LOCALS.
define nvidia_build_modularization_stub_filter_locals
$(strip \
  $(eval _need_locals := $(NVIDIA_BUILD_MODULARIZATION_STUB_NEEDS_LOCALS)) \
  $(foreach _v, $(_need_locals), $(eval _save_$(_v) := $($(_v)))) \
  $(eval include $(NVIDIA_CLEAR_VARS_INTERNAL)) \
  $(foreach _v, $(_need_locals), $(eval $(_v) := $(_save_$(_v)))) \
  $(foreach _v, $(_need_locals), $(eval _save_$(_v) := )) \
  $(eval _need_locals := ))
endef

define nvidia-generate-empty-file
  $1: PRIVATE_CUSTOM_TOOL = touch $$@
  $1:
	$$(transform-generated-source)
endef
