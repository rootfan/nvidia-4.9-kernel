# For now Java is kept outside the scope of Android build modularization.
# Report modularization support to keep user makefiles within modules simple,
# but only build the component as part of the system builder.
NVIDIA_TEMPLATE_SUPPORTS_BUILD_MODULARIZATION := true
NVIDIA_BUILD_MODULARIZATION_IS_STUBBED := 0

ifdef BUILD_BRAIN_MODULAR_NAME

# Module builder
include $(NVIDIA_POST_DUMMY)

else

# Monolithic build or system builder
LOCAL_MODULE_CLASS := JAVA_LIBRARIES
LOCAL_NO_2ND_ARCH_MODULE_SUFFIX := true

include $(NVIDIA_BASE)

ifeq ($(LOCAL_IS_NVIDIA_TEST),true)
ifneq ($(filter nvidia-tests,$(MAKECMDGOALS)),)
ifeq ($(LOCAL_MODULE_CLASS),JAVA_LIBRARIES)
# We want Nvidia java test libraries to be installed into same
# location as normal java libraries. Android build system would in
# default place them in location pointed by
# TARGET_OUT_DATA_JAVA_LIBRARIES (since LOCAL_MODULE_TAGS indicates
# them to be 'tests' components).
LOCAL_MODULE_PATH := $(TARGET_OUT_JAVA_LIBRARIES)
endif
endif
endif

include $(BUILD_JAVA_LIBRARY)
include $(NVIDIA_POST)

# BUILD_JAVA_LIBRARY doesn't consider additional dependencies
$(LOCAL_BUILT_MODULE): $(LOCAL_ADDITIONAL_DEPENDENCIES)
LOCAL_NO_2ND_ARCH_MODULE_SUFFIX :=

endif
