#
# Copyright (c) 2013-2017, NVIDIA CORPORATION.  All rights reserved.
#
# Nvidia CUDA target static library
#

################################################################################
# cuda_nvcc_setup.mk
#
# Input:  my_prefix
#         LOCAL_NVIDIA_NVCC_CFLAGS
#         LOCAL_NVIDIA_NVCC_LDFLAGS
#         LOCAL_*
#
# Output: my_nvcc          : NVIDIA Cuda Compiler binary location
#         my_nvcc_cflags   : Parameters for .cu to .o compilation
#         my_nvcc_ldflags  : Parameters for .o to library compilation
#
# Modify: LOCAL_EXPORT_C_INCLUDE_DIRS
################################################################################
include $(NVIDIA_BUILD_ROOT)/cuda_nvcc_setup.mk

################################################################################
# Using following variables from binary.mk
#
# my_cc:                    c/c++ compiler.
# my_cflags:                c flags generated by android build system.
# my_c_includes:            include pathes generated by android build system.
# my_target_c_includes:     stl/compiler specific include pathes generated by android build system.
# my_target_global_ldflags: linker flags generated by android build system.
# my_32_64_bit_suffix:      32/64 bit suffix for current build target.
# intermediates:            output path for intermediate objects.
# import_includes:          file that contains all include paths of dependent libraries.
################################################################################

# WAR: nvcc does not support ccache, disable it for cuda static libraries
_SAVE_CXX_WRAPPER := $(CXX_WRAPPER)
CXX_WRAPPER :=
include $(BUILD_SYSTEM)/binary.mk
CXX_WRAPPER := $(_SAVE_CXX_WRAPPER)

ifeq ($(LOCAL_IS_HOST_MODULE), true)
$(error cuda_nvcc_setup.mk supports target build only!)
endif

################################################################################
#
# CUDA Object Generation
#
################################################################################
cuda_sources := $(filter %.cu,$(LOCAL_SRC_FILES))
cuda_objects := $(addprefix $(intermediates)/,$(cuda_sources:.cu=.o))
cuda_objdeps := $(cuda_objects) $(cuda_depinfo)

ifneq ($(strip $(cuda_objects)),)
 include $(NVIDIA_BUILD_ROOT)/cuda_objects.mk
endif

################################################################################
#
# Linking
#
################################################################################

ifneq ($(strip $(cuda_objects)),)
$(LOCAL_BUILT_MODULE): PRIVATE_CC      := $(my_nvcc) -ccbin $(my_cxx)
$(LOCAL_BUILT_MODULE): PRIVATE_LDFLAGS := $(my_nvcc_ldflags) \
                                           $(addprefix -Xcompiler , $(my_target_global_ldflags))
$(LOCAL_BUILT_MODULE): $(cuda_objects)
	@mkdir -p $(dir $@)
	@rm -f $@
	@echo "target CUDA StaticLib: $(PRIVATE_MODULE) ($@)"
	$(hide) $(call split-long-arguments,$(PRIVATE_CC) $(PRIVATE_LDFLAGS) -o $@,$(filter %.o, $^))
	touch $(dir $@)export_includes

endif
