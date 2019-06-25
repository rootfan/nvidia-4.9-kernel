# For now Java is kept outside the scope of Android build modularization.
# Report modularization support to keep user makefiles within modules simple.
# The component can be triggered in system and module builds.
NVIDIA_TEMPLATE_SUPPORTS_BUILD_MODULARIZATION := true

LOCAL_MODULE_CLASS := JAVA_LIBRARIES

include $(BUILD_SYSTEM)/multilib.mk

include $(NVIDIA_BASE)
include $(BUILD_STATIC_JAVA_LIBRARY)
include $(NVIDIA_POST)

# BUILD_JAVA_LIBRARY doesn't consider additional dependencies
$(LOCAL_BUILT_MODULE): $(LOCAL_ADDITIONAL_DEPENDENCIES)
