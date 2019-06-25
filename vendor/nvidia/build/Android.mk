# HACKY: PDK fixups
ifeq ($(TARGET_BUILD_PDK),true)
LOCAL_2ND_ARCH_VAR_PREFIX :=
ifeq ($(TARGET_IS_64_BIT),true)
LOCAL_2ND_ARCH_VAR_PREFIX := $(TARGET_2ND_ARCH_VAR_PREFIX)
endif

$(call intermediates-dir-for,SHARED_LIBRARIES,libOpenSLES,,,$(LOCAL_2ND_ARCH_VAR_PREFIX))/export_includes:
	$(hide) mkdir -p $(dir $@) && rm -f $@
	$(hide) touch $@

$($(LOCAL_2ND_ARCH_VAR_PREFIX)TARGET_OUT_INTERMEDIATE_LIBRARIES)/libOpenSLES.so: $(PDK_FUSION_PLATFORM_ZIP)
	$(hide) unzip -p $(PDK_FUSION_PLATFORM_ZIP) system/lib/libOpenSLES.so >$@

LOCAL_2ND_ARCH_VAR_PREFIX :=

$(shell zip -q -d $(PDK_FUSION_PLATFORM_ZIP) "system/vendor/*")
endif
