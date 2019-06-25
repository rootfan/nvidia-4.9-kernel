# At this stage main makefiles, including product makefiles,
# have been read, so all major variables should be available.

LOCAL_PATH := $(call my-dir)

ifeq ($(wildcard $(PRODUCT_OUT)/blob),$(PRODUCT_OUT)/blob)
INSTALLED_RADIOIMAGE_TARGET += $(PRODUCT_OUT)/blob
endif

ifeq ($(wildcard $(PRODUCT_OUT)/bmp.blob),$(PRODUCT_OUT)/bmp.blob)
INSTALLED_RADIOIMAGE_TARGET += $(PRODUCT_OUT)/bmp.blob
endif

# add blob_unified to darcy/mdarcy target
ifneq ($(filter darcy% mdarcy%,$(TARGET_PRODUCT)),)
ifeq ($(wildcard $(PRODUCT_OUT)/blob_unified),$(PRODUCT_OUT)/blob_unified)
INSTALLED_RADIOIMAGE_TARGET += $(PRODUCT_OUT)/blob_unified
endif
endif
