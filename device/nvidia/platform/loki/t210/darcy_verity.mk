#Copyright (c) 2016, NVIDIA CORPORATION.  All rights reserved.
#
#NVIDIA Corporation and its licensors retain all intellectual property and
#proprietary rights in and to this software and related documentation.  Any
#use, reproduction, disclosure or distribution of this software and related
#documentation without an express license agreement from NVIDIA Corporation
#is strictly prohibited.

# Provides dependencies necessary for verified boot (only for user and
# userdebug builds)

user_variant := $(filter user userdebug,$(TARGET_BUILD_VARIANT))
ifneq (,$(user_variant))
    PRODUCT_SUPPORTS_BOOT_SIGNER := true
    PRODUCT_SUPPORTS_VERITY := true
    PRODUCT_SUPPORTS_VERITY_FEC := false

    # The dev key is used to sign boot and recovery images, and the verity
    # metadata table. Actual product deliverables will be re-signed by hand.
    # We expect this file to exist with the suffixes ".x509.pem" and ".pk8".
    PRODUCT_VERITY_SIGNING_KEY := build/target/product/security/verity

    PRODUCT_PACKAGES += \
            verity_key
endif
