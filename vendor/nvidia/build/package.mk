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

# Don't define the package if it uses android-support-* and we're building the PDK
ifeq ($(TARGET_BUILD_PDK),true)
ifneq ($(filter android-support-%,$(LOCAL_STATIC_JAVA_LIBRARIES)),)
LOCAL_STATIC_JAVA_LIBRARIES := ignore
$(warning Ignoring $(LOCAL_PACKAGE_NAME) because of dependency on android-support-*)
endif
ifneq ($(filter android-common,$(LOCAL_STATIC_JAVA_LIBRARIES)),)
LOCAL_STATIC_JAVA_LIBRARIES := ignore
$(warning Ignoring $(LOCAL_PACKAGE_NAME) because of dependency on android-common)
endif
endif

ifneq ($(LOCAL_STATIC_JAVA_LIBRARIES),ignore)
# Let NVIDIA_BASE know that this is a package
LOCAL_MODULE_CLASS := APPS
include $(NVIDIA_BASE)
LOCAL_MODULE_CLASS :=
include $(BUILD_PACKAGE)
include $(NVIDIA_POST)

# BUILD_PACKAGE doesn't consider additional dependencies
$(LOCAL_BUILT_MODULE): $(LOCAL_ADDITIONAL_DEPENDENCIES)
endif

endif
