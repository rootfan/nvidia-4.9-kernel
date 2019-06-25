#Copyright (c) 2015-2017 NVIDIA Corporation.  All Rights Reserved.
#
#NVIDIA Corporation and its licensors retain all intellectual property and
#proprietary rights in and to this software and related documentation.  Any
#use, reproduction, disclosure or distribution of this software and related
#documentation without an express license agreement from NVIDIA Corporation
#is strictly prohibited.

#!/bin/bash

#
# Script to generate blob.
#
# This script is based on original signing script located,
# http://git-master/r/gitweb?p=tegra/git-tools.git;a=blob_plain;f=signing/configs/Loki/prod-loki/generic/common.conf;hb=HEAD
# and
# http://git-master/r/gitweb?p=tegra/git-tools.git;a=tree;f=signing/configs/Loki/prod-loki/loki_e_wifi;h=b4392b27233050b88819fdf3ed6121860938a0e5;hb=HEAD

if [ ! -d $ANDROID_BUILD_TOP/vendor/nvidia/tegra/core-private ]; then
    echo "Generating nv-blob in customer build is not supported\n";
    exit
fi

# Set options.

set -e
set -u

# Set the input files to use.

BOARD_NAME=$TARGET_PRODUCT

# Multiple BCTs are not supported yet
# Add multiple DTBs seperated by comma
# For now, add all the relevant DTBs present in $OUT

CFG_FILE="flash_t210_android_sdmmc_fb.xml"
BCT_FILE="bct_p2530_e01.cfg"
ODM_DATA="0x694000"
case ${BOARD_NAME} in
    t210ref | t210ref_gms | t210ref_int)
        DTB_FILE=$(ls -m $OUT/tegra210*jetson*.dtb $OUT/tegra210*ers*.dtb | awk -F '/' '{print $NF}')
        ODM_DATA="0x84000"
        ;;

    loki_e_wifi | loki_e_tab_os)
        DTB_FILE=$(ls -m $OUT/tegra210*loki*.dtb | awk -F '/' '{print $NF}')
        ODM_DATA="0x694000"
        ;;
    foster_e)
        DTB_FILE=$(ls -m $OUT/tegra210*foster-e-*.dtb | awk -F '/' '{print $NF}')
        ODM_DATA="0x294000"
        ;;
    foster_e_hdd)
        BCT_FILE="bct_p2530_sata_e01.cfg"
        CFG_FILE="flash_t210_android_sata_fb.xml"
        DTB_FILE=$(ls -m $OUT/tegra210*foster-e-hdd-*.dtb | awk -F '/' '{print $NF}')
        ODM_DATA="0x294000"
        ;;
    darcy | mdarcy)
        BCT_FILE="bct_p2894.cfg"
        BCTB01_FILE="bct_p2894_t210b01.cfg"
        CFG_FILE="flash_t210_darcy_android_sdmmc.xml"
        CFGB01_FILE="flash_t210b01_darcy_android_sdmmc.xml"
        DTB_FILE=$(ls -m $OUT/tegra210*darcy*.dtb | awk -F '/' '{print $NF}')
        ODM_DATA="0x1294000"
        ;;
    sif)
        BCT_FILE="bct_p3425.cfg"
        CFG_FILE="flash_t210b01_sif_android_sdmmc.xml"
        DTB_FILE=$(ls -m $OUT/tegra210*sif*.dtb | awk -F '/' '{print $NF}')
        ODM_DATA="0x1294000"
        ;;
    *)
        echo "Unsupported board: ${BOARD_NAME}"
        echo "OTA Blob creation failed"
        exit 0
        ;;
esac

# Sign the bootloader.

cd ${OUT}
case ${BOARD_NAME} in
    t210ref | t210ref_gms | t210ref_int | loki_e_wifi | loki_e_tab_os | foster_e | foster_e_hdd)
        echo ""
        echo "Generating fuse_bypass.bin..."
        CMD="$ANDROID_HOST_OUT/bin/tegraparser --fuseconfig fuse_bypass.xml \
            --sku acr-debug"
        echo ""
        echo $CMD
        echo ""
        eval $CMD
        echo ""
        echo "Generating signed .bin files..."
        echo ""
        CMD="$ANDROID_HOST_OUT/bin/tegraflash.py \
            --bct ${BCT_FILE} \
            --bl cboot.bin \
            --cfg ${CFG_FILE} \
            --odmdata ${ODM_DATA} \
            --applet nvtboot_recovery.bin \
            --chip 0x21 \
            --key none \
            --cmd \"sign\" \
            --fb fuse_bypass.bin "

        echo $CMD
        eval $CMD
        echo ""
        echo "Updating the blob..."
        CMD="$ANDROID_HOST_OUT/bin/nvblob_v2 \
            -t update \
            signed/nvtboot.bin.encrypt NVC 2 \
            signed/nvtboot.bin.encrypt NVC-B 2 \
            bpmp.bin BPF 2 \
            signed/nvtboot_cpu.bin.encrypt TBC 2 \
            signed/nvtboot_cpu.bin.encrypt TBC-B 2 \
            signed/cboot.bin.encrypt EBT 2 \
            signed/cboot.bin.encrypt RBL 2 \
            signed/warmboot_fb.bin.encrypt WB0 2 \
            signed/tos.img.encrypt TOS 2 \
            signed/${BCT_FILE/.cfg/.bct} BCT 2 "

        for i in $(echo $DTB_FILE | tr "," "\n")
        do
            CMD=${CMD}" $i DTB 2 "
            CMD=${CMD}" $i RP1 2 "
        done
        echo ""
        echo $CMD
        echo ""
        eval $CMD && mv ota.blob blob
        ;;
    sif)
        echo ""
        echo "Generating fuse_bypass.bin..."
        CMD="$ANDROID_HOST_OUT/bin/tegraparser --fuseconfig fuse_bypass.xml \
            --sku acr-debug"
        echo ""
        echo $CMD
        echo ""
        eval $CMD
        echo ""
        echo "Generating signed .bin files..."
        echo ""
        CMD="$ANDROID_HOST_OUT/bin/tegraflash.py \
            --bct ${BCT_FILE} \
            --bl cboot.bin \
            --cfg ${CFG_FILE} \
            --odmdata ${ODM_DATA} \
            --applet nvtboot_recovery_t210b01.bin \
            --chip \"0x21 0x2\" \
            --key none \
            --cmd \"sign\" \
            --fb fuse_bypass.bin "

        echo $CMD
        eval $CMD
        echo ""
        echo "Updating the blob..."
        CMD="$ANDROID_HOST_OUT/bin/nvblob_v2 \
            -t update \
            signed/nvtboot_t210b01_header.bin.encrypt NVC 2 \
            signed/nvtboot_t210b01_header.bin.encrypt NVC-B 2 \
            bpmp_p3425_sif_t210b01.bin BPF 2 \
            signed/nvtboot_cpu.bin.encrypt TBC 2 \
            signed/nvtboot_cpu.bin.encrypt TBC-B 2 \
            signed/cboot.bin.encrypt EBT 2 \
            signed/cboot.bin.encrypt RBL 2 \
            signed/warmboot_fb.bin.encrypt WB0 2 \
            signed/tlk_tos_t210b01.img.encrypt TOS 2 \
            signed/${BCT_FILE/.cfg/.bct} BCT 2 "

        for i in $(echo $DTB_FILE | tr "," "\n")
        do
            CMD=${CMD}" $i DTB 2 "
            CMD=${CMD}" $i RP1 2 "
        done
        echo ""
        echo $CMD
        echo ""
        eval $CMD && mv ota.blob blob
        ;;
    darcy | mdarcy)
        echo ""
        echo "Generating nct for t210b01..."
        echo ""
        CMD="python tnspec.py nct new p2894-0050-a08-t210b01 \
            -o nct_t210b01.bin --spec tnspec.json"
        echo ""
        echo $CMD
        echo ""
        eval $CMD
        echo ""
        echo "Generating fuse_bypass.bin..."
        CMD="$ANDROID_HOST_OUT/bin/tegraparser --fuseconfig fuse_bypass.xml \
            --sku acr-debug"
        echo ""
        echo $CMD
        echo ""
        eval $CMD
        echo ""
        echo "Generating signed t210b01 .bin files..."
        echo ""
        CMD="$ANDROID_HOST_OUT/bin/tegraflash.py \
            --bct ${BCTB01_FILE} \
            --bl cboot.bin \
            --cfg ${CFGB01_FILE} \
            --odmdata ${ODM_DATA} \
            --applet nvtboot_recovery_t210b01.bin \
            --nct nct_t210b01.bin \
            --chip \"0x21 0x2\" \
            --key none \
            --cmd \"sign\" \
            --fb fuse_bypass.bin "

        echo $CMD
        eval $CMD
        mv -f signed signed_t210b01
        echo ""
        echo "Generating signed .bin files..."
        echo ""
        CMD="$ANDROID_HOST_OUT/bin/tegraflash.py \
            --bct ${BCT_FILE} \
            --bl cboot.bin \
            --cfg ${CFG_FILE} \
            --odmdata ${ODM_DATA} \
            --applet nvtboot_recovery.bin \
            --chip 0x21 \
            --key none \
            --cmd \"sign\" \
            --fb fuse_bypass.bin "

        echo $CMD
        eval $CMD
        echo ""
        echo "Updating unified blob..."
        CMD="$ANDROID_HOST_OUT/bin/nvblob_v2 \
            -t update \
            signed/cboot.bin.encrypt EBT 2 \
            signed/cboot.bin.encrypt RBL 2 \
            bpmp.bin BPF 2 \
            signed/nvtboot.bin.encrypt NVC 2 \
            signed/nvtboot.bin.encrypt NVC-B 2 \
            signed/nvtboot_cpu.bin.encrypt TBC 2 \
            signed/nvtboot_cpu.bin.encrypt TBC-B 2 \
            signed/warmboot_fb.bin.encrypt WB0 2 \
            signed/tos.img.encrypt TOS 2 \
            signed/${BCT_FILE/.cfg/.bct} BCT 2 "

        for i in $(echo $DTB_FILE | tr "," "\n")
        do
            CMD=${CMD}" $i DTB 2 "
            CMD=${CMD}" $i RP1 2 "
        done

        CMD=${CMD}" rp4.blob RP4 2 \
            signed_t210b01/nvtboot_cpu.bin.encrypt T210B01_TBC 2 \
            signed_t210b01/nvtboot_cpu.bin.encrypt T210B01_TBC-B 2 \
            signed_t210b01/cboot.bin.encrypt T210B01_EBT 2 \
            signed_t210b01/cboot.bin.encrypt T210B01_RBL 2 \
            signed_t210b01/nvtboot_t210b01_header.bin.encrypt T210B01_NVC 2 \
            signed_t210b01/nvtboot_t210b01_header.bin.encrypt T210B01_NVC-B 2 \
            bpmp_p2894_darcy_t210b01.bin T210B01_BPF 2 \
            signed_t210b01/warmboot_fb.bin.encrypt T210B01_WB0 2 \
            signed_t210b01/tlk_tos_t210b01.img.encrypt T210B01_TOS 2 \
            signed_t210b01/${BCTB01_FILE/.cfg/.bct} T210B01_BCT 2 "

        echo ""
        echo $CMD
        echo ""
        eval $CMD && mv ota.blob blob_unified

        echo ""
        echo "Updating blob (for older T210 Darcy Bootloader)..."
        CMD="$ANDROID_HOST_OUT/bin/nvblob_v2 \
            -t update \
            signed/cboot.bin.encrypt EBT 2 \
            signed/cboot.bin.encrypt RBL 2 \
            bpmp.bin BPF 2 \
            signed/nvtboot.bin.encrypt NVC 2 \
            signed/nvtboot.bin.encrypt NVC-B 2 \
            signed/nvtboot_cpu.bin.encrypt TBC 2 \
            signed/nvtboot_cpu.bin.encrypt TBC-B 2 \
            signed/warmboot_fb.bin.encrypt WB0 2 \
            signed/tos.img.encrypt TOS 2 \
            signed/${BCT_FILE/.cfg/.bct} BCT 2 "

        for i in $(echo $DTB_FILE | tr "," "\n")
        do
            CMD=${CMD}" $i DTB 2 "
            CMD=${CMD}" $i RP1 2 "
        done

        echo ""
        echo $CMD
        echo ""
        eval $CMD && mv ota.blob blob

        ;;
    *)
        echo "Unsupported board: ${BOARD_NAME}"
        echo "OTA Blob creation failed"
        exit 0
        ;;
esac

echo ""
echo "OTA Blob creation successful"
echo ""
