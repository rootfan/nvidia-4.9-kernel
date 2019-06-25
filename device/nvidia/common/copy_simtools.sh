#!/bin/bash
#
# Copyright (c) 2012-2016, NVIDIA CORPORATION. All rights reserved.
#
# Usage: copy_simtools.sh [--help]
#
# Description: Copy the simtools scripts and testlists so they can be packaged
#              with other binaries and images.
#-------------------------------------------------------------------------------

if [ "$1" == "--help" ]; then
    this_script=`basename $0`

    cat <<EOF

    Copy the simtools scripts and testlists so they can be packaged
    with other binaries and images.

    Usage:

          $this_script [--help]

EOF
    exit 0
fi

# Sanity checks & default option processing
if [ -z "$ANDROID_BUILD_TOP" ]; then
    echo "ERROR: You must set environment variable ANDROID_BUILD_TOP to the top of your repo tree"
    exit 2
fi

if [ -z "$OUT" ]; then
    echo "ERROR: You must set environment variable OUT to the output directory"
    exit 2
fi

if [ "$ANDROID_BUILD_TOP" == "." ]; then
    top=`pwd`
else
    top=$ANDROID_BUILD_TOP
fi

SIMTOOLS=$top/vendor/nvidia/tegra/simtools

if [ ! -d "$OUT" ]; then
    echo "ERROR: Product output directory $OUT does not exist."
    exit 2
fi

if [ ! -d $SIMTOOLS ]; then
    echo "ERROR: simtools directory $SIMTOOLS does not exits."
    exit 2
fi

echo "Copying the simtools directory..."
rm -rf $OUT/system/simtools
mkdir $OUT/system/simtools
cp -R $SIMTOOLS/* $OUT/system/simtools/.
status=$?

if [ $status == 0 ]; then
    echo "Done"
fi
exit $status
