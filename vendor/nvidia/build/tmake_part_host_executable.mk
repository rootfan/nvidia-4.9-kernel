################################### tell Emacs this is a -*- makefile-gmake -*-
#
# Copyright (c) 2014, NVIDIA CORPORATION.  All rights reserved.
#
# NVIDIA CORPORATION and its licensors retain all intellectual property
# and proprietary rights in and to this software, related documentation
# and any modifications thereto.  Any use, reproduction, disclosure or
# distribution of this software and related documentation without an express
# license agreement from NVIDIA CORPORATION is strictly prohibited.
#
###############################################################################
#
# Convenience makefile fragment for host executable from tmake part umbrella
#
###############################################################################

LOCAL_IS_HOST_MODULE := true
LOCAL_MODULE_CLASS   := EXECUTABLES

include $(NVIDIA_TMAKE_PART)

# Local Variables:
# indent-tabs-mode: t
# tab-width: 8
# End:
# vi: set tabstop=8 noexpandtab:
