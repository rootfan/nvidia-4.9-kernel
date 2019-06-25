#!/bin/bash

# Copyright (c) 2013-2016 NVIDIA Corporation.  All rights reserved.
#
# NVIDIA Corporation and its licensors retain all intellectual property
# and proprietary rights in and to this software, related documentation
# and any modifications thereto.  Any use, reproduction, disclosure or
# distribution of this software and related documentation without an express
# license agreement from NVIDIA Corporation is strictly prohibited.

# ========================================
#   SDMMC/EMMC image creation helpers
# ========================================

create_image()
{
  test -f $1 && rm -f $1
  dd bs=1M count=1 seek=$(($2-1)) if=/dev/zero of=$1 >/dev/null 2>&1
}

# Begin partitioning
# args: <image>
begin_partitioning()
{
  parted -s $1 mklabel gpt
  export __IMAGE_PART__=$1
}

# Make one partition
# args: <image> <label> <start> <end>
make_part()
{
  local image=`shift`
  parted -s $__IMAGE_PART__ mkpart $@
}

# End partitioning
# args: <image>
end_partitioning()
{
  parted -s $__IMAGE_PART__ print
  export __IMAGE_PART__=
}

# sandbox a partition as loop device
# args:
#   $1: image file
#   $2: partition name
#   $3: callback function
#
# Examples:
#   1) write a partition from a directory
#      process_image <image> <label> /path/to/dir
#
#   2) write a partition w/ a populate callback
#      callback()
#      {
#         populate ... into <dir> (eg. sandbox)
#         echo "<dir>"
#      }
#      process_image <image> <label> callback
#
#   3) write a partition from an existing image
#      process_image <image> <label> /path/to/some.img
#
#   4) create a blank ext4 partition
#      process_image <image> <label>
#
process_image()
{
  local image=$1
  local pname=$2
  local cbcmd=$3
  local sandbox=`create_sandbox`
  local subimg=$sandbox/$pname.img

  cbcmd=`eval "echo $cbcmd"`

  # Execute callback
  if [ -f $cbcmd ] || [ -d $cbcmd ]; then
    local content=$cbcmd
  else
    local content=`eval $cbcmd`
  fi

  # Get layout
  local parted_cmd="parted -s $image unit B print | grep $pname"
  local size=`eval $parted_cmd | awk '{ print $4; }' | cut -d'B' -f1`
  local offs=`eval $parted_cmd | awk '{ print $2; }' | cut -d'B' -f1`

  # Create sub-image
  if [ -z $content ] || [ -d $content ]; then
    # Blank or directory source
    $ANDROID_HOST_OUT/bin/make_ext4fs -l $size -b 1024 $subimg $content >/dev/null 2>&1
  else
    local sandbox=`create_sandbox`
    # Image source
    $ANDROID_HOST_OUT/bin/simg2img $content $sandbox/$(basename $content) >/dev/null 2>&1
    if [ $? != 0 ]; then
      # non-sparsed image
      subimg=$content
    else
      # sparsed image
      subimg=$sandbox/$(basename $content)
    fi
  fi

  # Write the image
  dd bs=512 if=$subimg of=$image seek=$(($offs/512)) conv=notrunc >/dev/null 2>&1

  rm -rf $sandbox
}

# Create a temporary storage
create_sandbox()
{
  echo $(mktemp -d)
}

# Comporess the image w/ gzip
# args: <image>
compress_image()
{
  gzip -f --best $1
}

print_usage()
{
  echo "Usage: $0 [OPTION]..."
  echo "Create an emmc/sdmmc image based on config file."
  echo "Options:"
  echo "  -o          file name of the output image."
  echo "  -s          size of the output image in MB."
  echo "  -c          config that describe the disk layout."
  echo "  -z          use gzip to compress the image."
  echo "  -h          display this message."
  echo ""
  echo "Config syntax:"
  echo "  <mount point> <start> <end> [content] where content"
  echo "can be an image file, a directory, or null for blank"
  echo "EXT4 partition. Environment variable will be evaluated."
  echo ""
  echo "Example:"
  echo "  APP 1M 1024M \$OUT/full_filesystem"
  echo "  UDA 1025M 1280M \$OUT/userdata.img"
  echo "  CAC 1281M 1536M"
  echo "  MSC 1537M 1792M"
}

generate_sdmmc_from_config()
{
  local image
  local size
  local partcfg
  local do_gzip=0

  while getopts "o:s:c:zh" flag
  do
    case $flag in
     o)
       image=$OPTARG
       ;;
     s)
       size=$OPTARG
       ;;
     c)
       partcfg=$OPTARG
       ;;
     z)
       do_gzip=1
       ;;
     h)
       print_usage
       exit 0
       ;;
     esac
  done

  if [ -z $image ]; then
    echo "ERROR: invalid image file \"$image\"."
    print_usage
    exit 1
  fi
  if [[ $size =~ ^[0-9]+$ ]]; then
    echo "" # PASS
  else
    echo "ERROR: invalid image size \"$size\"."
    print_usage
    exit 1
  fi
  if [ ! -f $partcfg ]; then
    echo "ERROR: invalid config file \"$image\"."
    print_usage
    exit 1
  fi

  create_image $image $size

  local line
  local config
  begin_partitioning $image
    while read line; do
      config=$(echo $line | cut -d' ' -f1-3)
      make_part $config
      if [ $? -ne 0 ]; then
        echo "ERROR: failed to create \"$config\""
        print_usage
        exit 1
      fi
    done <$partcfg
  end_partitioning

  while read line; do
    local pname=$(echo $line | cut -d' ' -f1)
    local content=$(echo $line | cut -d' ' -f4)
    if [ -z $content ]; then
      printf "==> Formatting $pname into blank ext4 partition ... "
    else
      printf "==> Formatting $pname with $content ... "
    fi
    process_image $image $pname $content
    echo "DONE"
  done <$partcfg

  if [ $do_gzip -eq 1 ]; then
    echo "==> Compressing $image ..."
    compress_image $image
  fi

  echo ""
  echo "SUCCESS"
}

# Standalone mode
if [[ $0 =~ 'sdmmc_util.sh' ]]; then
  generate_sdmmc_from_config "$@"
fi

