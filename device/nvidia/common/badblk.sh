#!/system/bin/sh

# Copyright (c) 2017, NVIDIA CORPORATION. All rights reserved.
#
# NVIDIA CORPORATION and its licensors retain all intellectual property
# and proprietary rights in and to this software, related documentation
# and any modifications thereto.  Any use, reproduction, disclosure or
# distribution of this software and related documentation without an express
# license agreement from NVIDIA CORPORATION is strictly prohibited.

if [[ "x$1" == "x" ]]; then
	exit 0
fi
val=`cat /data/badblk/badblock.log | grep $1`
if [[ "x$val" == "x" ]]; then
	echo $1 >> /data/badblk/badblock.log
	var1=$(($1 - 10));
	var2=$(($1 + 10));
	t=$(/system/bin/badblocks -b 4096 -o /data/badblk/badblock_cmd.log /dev/block/$2 $var2 $var1)
	t=$(/system/bin/e2fsck -y  -l /data/badblk/badblock_cmd.log /dev/block/$2 > /dev/null)
fi
