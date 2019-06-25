# This file needs to be included after the core Android build (base_rules.mk)

ifneq ($(NVIDIA_CLEARED),false)
$(error $(LOCAL_PATH):$(LOCAL_MODULE): NVIDIA_BASE not included)
endif
ifeq ($(NVIDIA_POST_INCLUDED),true)
$(error $(LOCAL_PATH):$(LOCAL_MODULE): NVIDIA_POST included twice)
endif
NVIDIA_POST_INCLUDED := true

# Get a list of all possible registered targets
NVIDIA_TARGETS := $(LOCAL_MODULE)
ifdef LOCAL_IS_HOST_MODULE
NVIDIA_TARGETS += $(LOCAL_MODULE)$(HOST_2ND_ARCH_MODULE_SUFFIX)
else
ifdef TARGET_2ND_ARCH
NVIDIA_TARGETS += $(LOCAL_MODULE)$(TARGET_2ND_ARCH_MODULE_SUFFIX)
endif
endif

# Prune out all targets that weren't defined
NVIDIA_TARGETS := $(filter $(NVIDIA_TARGETS),$(ALL_MODULES))

# Add to nvidia module list
ALL_NVIDIA_MODULES += $(NVIDIA_TARGETS)

# Generate a module-build target that depends on all drivers and tests
# belonging to the current build module.
ifdef BUILD_BRAIN_MODULAR_NAME
  ifeq ($(NVIDIA_BUILD_MODULARIZATION_NAME),$(BUILD_BRAIN_MODULAR_NAME))
    module-build: $(NVIDIA_TARGETS)
  endif
endif

# Add to nvidia goals
nvidia-clean: $(foreach target,$(NVIDIA_TARGETS),clean-$(target))

ifeq ($(LOCAL_IS_NVIDIA_TEST),true)
  nvidia-tests: $(NVIDIA_TARGETS)
  ifneq ($(filter nvidia-tests nvidia-tests-automation,$(MAKECMDGOALS)),)
    # If we're explicitly building nvidia-tests, install the tests.
    ALL_NVIDIA_TESTS += $(NVIDIA_TARGETS)
  endif
else # not nvidia-test component
  nvidia-modules: $(NVIDIA_TARGETS)
endif

# Clean local variables
NVIDIA_TARGETS :=

# Restore some global variables possibly modified by the templates
CC_WRAPPER := $(NVIDIA_SAVED_CC_WRAPPER)
CXX_WRAPPER := $(NVIDIA_SAVED_CXX_WRAPPER)

include $(NVIDIA_BUILD_MODULARIZATION_CLEAR)
