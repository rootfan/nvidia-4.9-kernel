#!/bin/bash
#
# Copyright (c) 2013-2016, NVIDIA CORPORATION.  All rights reserved.
#
# NVFlash wrapper script for flashing Android from either build environment
# or from a BuildBrain output.tgz package. This script is usually
# called indirectly via vendorsetup.sh 'flash' function or BuildBrain
# package flashing script.
#

###############################################################################
# Usage
###############################################################################
usage()
{
    _margin="    "
    _cl="1;4;" \
    pr_info   "Usage:"
    pr_info   ""
    pr_info   "flash.sh [-h] [-n] [-w <{0,1,2,3}>] [-o <odmdata>] [-s <skuid> [forcebypass]]" "$_margin"
    pr_info   "         [-d] [-e] [-z] [-b <{0,1}>] [-r] [-N]" "$_margin"
    pr_info   "         [-f] [-m <modem>] [-p] [-P <pathtopartitions>] [-X] [-S] [-- [optional args]]" "$_margin"

    pr_info_b "-h" "$_margin"
    pr_info   "  Prints help " "$_margin"
    pr_info_b "-b" "$_margin"
    pr_info   "  Set/Reset battery odmdata bit" "$_margin"
    pr_info_b "-w" "$_margin"
    pr_info   "  Set/Reset watchdog odmdata bit" "$_margin"
    pr_info   "  0 :- WDT Disabled" "$_margin"
    pr_info   "  1 :- AP WDT Enabled" "$_margin"
    pr_info   "  2 :- PMIC WDT Enabled" "$_margin"
    pr_info   "  3 :- Both WDT Enabled" "$_margin"
    pr_info_b "-r" "$_margin"
    pr_info   "  Remembers the board selection (alternatively BOARD env variable can be set)" "$_margin"
    pr_info_b "-n" "$_margin"
    pr_info   "  Skips using sudo on cmdline" "$_margin"
    pr_info_b "-o" "$_margin"
    pr_info   "  Specify ODM data to use" "$_margin"
    pr_info_b "-s" "$_margin"
    pr_info   "  Specify SKU to use, with optional forcebypass flag to nvflash" "$_margin"
    pr_info_b "-m" "$_margin"
    pr_info   "  Specify modem to use ([-o <odmdata>] overrides this option)" "$_margin"
    pr_info_b "-f" "$_margin"
    pr_info   "  For fused devices. uses blob.bin and bootloader_signed.bin when specified." "$_margin"
    pr_info_b "-z" "$_margin"
    pr_info   "  Diags target. This is a flash target for diags." "$_margin"
    pr_info_b "-e" "$_margin"
    pr_info   "  Erase all partitions on device first. Do not backup any partitions" "$_margin"
    pr_info_b "-d" "$_margin"
    pr_info   "  Dry-run. Exits after printing out the final flash command" "$_margin"
    pr_info_b "-r" "$_margin"
    pr_info   "  Remembers the board selection (alternatively BOARD env variable can be set)" "$_margin"
    pr_info_b "-p" "$_margin"
    pr_info   "  Use pre backed up partitions for EKS,FCT,NCT in ~/.partsback" "$_margin"
    pr_info_b "-P" "$_margin"
    pr_info   "  Use pre backed up partitions for EKS,FCT,NCT in the specified folder" "$_margin"
    pr_info_b "-X" "$_margin"
    pr_info   "  Uses experimental features." "$_margin"
    pr_info_b "-N" "$_margin"
    pr_info   "  Don't track. Disables tracking board." "$_margin"
    pr_info_b "-S" "$_margin"
    pr_info   "  Switches to a new target without deleting SN." "$_margin"
    pr_info   ""
    pr_info__ "Note:" "$_margin"
    pr_info   "  Optional arguments after '--' are added as-is to nvflash cmdline before" "$_margin"
    pr_info   "  '--go' argument, which must be last." "$_margin"
    pr_info   ""
    pr_info   "  Option precedence is as follows:" "$_margin"
    pr_info   ""
    pr_info   "   1. Command-line options override all others." "$_margin"
    pr_info   "      (assuming there are alternative configurations to choose from:)" "$_margin"
    pr_info   "   2. Shell environment variables (BOARD, for predefining target board)" "$_margin"
    pr_info   "   3. If shell is interactive, prompt for input from user" "$_margin"
    pr_info   "   4. If shell is non-interactive, use default values" "$_margin"
    pr_info   "    - Shell is non-interactive in mobile sanity testing!" "$_margin"
    pr_info   ""
    pr_info__ "Environment Vairables:" "$_margin"
    pr_info   "PRODUCT_OUT    - target build output files (default: current directory)" "$_margin"
    [[ -n "${PRODUCT_OUT}" ]] && \
    pr_warn   "                     \"${PRODUCT_OUT}\" $_margin" || \
    pr_err    "                 Currently Not Set!" "$_margin"
    pr_info   "HOST_BIN       - path to flash executable (default: ./)" "$_margin"
    [[ -n "${HOST_BIN}" ]] && \
    pr_warn   "                     \"${HOST_BIN}\" $_margin" || \
    pr_err    "                 Currently Not Set!" "$_margin"
    pr_info   "BOARD          - Select board without a prompt. (default: None)" "$_margin"
    [[ -n "${BOARD}" ]] && \
    pr_warn   "                     \"${BOARD}\" $_margin" || \
    pr_err    "                 Currently Not Set!" "$_margin"
    pr_info   ""
}

###############################################################################
# TNSPEC Platform Handler
###############################################################################
tnspec_platforms()
{
    local product="$1"
    local tnlast=$PRODUCT_OUT/.tnspec_history
    specid=''
    nctbin=$PRODUCT_OUT/nct.bin
    # Debug
    TNSPEC_OUTPUT=${TNSPEC_OUTPUT:-/dev/null}

    # Tegranote boards are handled by an external tnspec.py utility
    local boards=$(tnspec spec list all -g hw)
    if [[ -z $board ]] && _shell_is_interactive; then
        _cl="1;4;" pr_ok_bl "Supported HW List for $product" "TNSPEC: "
        pr_warn "Choose \"auto\" to automatically detect HW" "TNSPEC: "
        tnspec spec list -v -g hw
        # Prompt user for target board info
        pr_info ""
        pr_info_b "'help' - usage, 'list' - list frequently used, 'all' - list all supported"
        [ -f $tnlast ] && board_default="$(cat $tnlast)"
        board_default=${board_default:-auto}
        _cl="1;" pr_ok "[Press Enter to choose \"$board_default\"]"
        _choose "DEFAULT:\"$board_default\" >> " "auto $boards" board simple

    else
        board=${board-auto}
    fi

    # Auto mode
    if [ $board == "auto" ]; then
        specid=$(tnspec_auto $nctbin)
        TNSPEC_UPDATE_NCT_ONLY=${TNSPEC_UPDATE_NCT_ONLY:-"no"}
        if [ -z "$specid" ]; then
                       pr_info   ""
            _cl="1;4;" pr_err    "SOMETHING WENT WRONG."
                       pr_info   ""
            _cl="4;"   pr_info__ "Run it again with TNSPEC_OUTPUT=/dev/stderr. (in recovery mode):"
                       pr_info   "e.g. "
                       pr_info_b "$ TNSPEC_OUTPUT=/dev/stderr ./flash.sh"
                       pr_info   ""
            # if TNSPEC_UPDATE_NCT_ONLY="yes", reset the device and exit.
            if [[ "$TNSPEC_UPDATE_NCT_ONLY" == "yes" ]]; then
                pr_err "NCT update failed. Quitting..." "TNSPEC: " >&2
                # XXX - to be cleaned up
                [ "$flash_driver" == "tegraflash" ] && \
                    (cd $PRODUCT_OUT && $(nvbin tegraflash.py) $flash_params --cmd "reboot") || \
                    recovery="--force_reset reset 100" _nvflash 2> $TNSPEC_OUTPUT >&2
                exit 1
            fi

            pr_err "Couldn't find SW Spec ID. Try choosing from the HW list." "TNSPEC: ">&2
            if _shell_is_interactive; then
                _choose ">> " "$boards" board
            else
                pr_warn "Try setting 'BOARD' env variable directly." "TNSPEC: ">&2
                exit 1
            fi
        else
            # if TNSPEC_UPDATE_NCT_ONLY="yes", reset the device and exit.
            if [[ "$TNSPEC_UPDATE_NCT_ONLY" == "yes" ]]; then
                # XXX - to be cleaned up
                [ "$flash_driver" == "tegraflash" ] && \
                    (cd $PRODUCT_OUT && $(nvbin tegraflash.py) $flash_params --cmd "reboot") || \
                    recovery="--force_reset reset 100" _nvflash 2> $TNSPEC_OUTPUT >&2
                exit 0
            fi

            [ "$flash_driver" != "tegraflash" ] && {
                # WAR: setting 'nct' shouldn't be needed if NCT's board id is understood by
                #      Tboot and BL natively.
                tnspec nct dump nct -n $nctbin > ${nctbin}.txt
                nct="--nct $(_os_path ${nctbin}.txt)"
                _su rm $nctbin
            }
        fi
    fi

    if  [ $board != "auto" ]; then

        # TEMPROARY BIG FAT WARNING
        _shell_is_interactive && [[ -z $_switch_target ]] \
            && [ "$flash_driver" == "tegraflash" ] && {

            pr_err "*******************************************************" "ERROR: "
            pr_err "*******************************************************" "ERROR: "
            pr_err "*******************************************************" "ERROR: "
            pr_err "*******************************************************" "ERROR: "
            pr_err "*******************************************************" "ERROR: "
            pr_err "*****                                             *****" "ERROR: "
            pr_err "*****   PLEASE USE '-S' OPTION TO SWITCH TARGET   *****" "ERROR: "
            pr_err "*****   (flash -S OR ./flash.sh -S)               *****" "ERROR: "
            pr_err "*****                                             *****" "ERROR: "
            pr_err "*******************************************************" "ERROR: "
            pr_err "*******************************************************" "ERROR: "
            pr_err "*******************************************************" "ERROR: "
            pr_err "*******************************************************" "ERROR: "
            pr_err "*******************************************************" "ERROR: "
            pr_info ""
            pr_info__ "IF YOU WANT TO CONITNUE, TYPE \"YES\" OR HIT <ENTER> TO QUIT"
            pr_info_b "-- STRONGLY RECOMMENDED TO JUST QUIT --"
            pr_info ""
            local _sayno
            read -e -p "HIT <ENTER> TO QUIT >> " _sayno
            [ "$_sayno" != "YES" ] && exit 1
        }

        if ! _in_array $board $boards; then
            pr_err "HW Spec ID '$board' is not supported. Choose one from the list." "TNSPEC: "
            tnspec spec list all -v -g hw
            exit 1
        fi

	signed_bin $board

        _cl="1;" pr_err "\"$board\" selected instead of \"auto\". Everything on the target will be removed." "TNSPEC: "

        specid=$(tnspec_manual $nctbin)
        if [ -z $specid ]; then
            pr_err "Couldn't find SW Spec ID. Spec needs to be updated." "TNSPEC: ">&2
            exit 1
        fi
        # override nct if SW spec doesn't use NCT.
        local skip_nct=$(tnspec spec get $specid.skip_nct -g sw)

        if [ -z $skip_nct ]; then
            pr_info "NCT created." "TNSPEC: "
            # print new nct
            tnspec nct dump -n $nctbin
            # generate nct
            tnspec nct dump nct -n $nctbin > ${nctbin}.txt
            nct="--nct $(_os_path ${nctbin}.txt)"
        else
            pr_warn "$specid doesn't use NCT." "TNSPEC: "
        fi
        # XXX - clean this up.
        flash_app=$(tnspec spec get $specid.flash_app -g sw)
    fi

    # save $board
    [[ -n $_remember_board ]] && {
        _cl="4;" pr_ok_bl "Saving board \"$board\" as default." "TNSPEC: "
        echo $board > $tnlast
    }

    sw_specs=$(tnspec spec list all -g sw)
    if ! _in_array $specid $sw_specs; then
        pr_warn "$specid is not supported. Please file a bug." "TNSPEC: "
        exit 1
    fi
    # set bctfile and cfgfile based on target board
    # 'unset' forces to use default values.

    if _in_array $specid $sw_specs; then
        cfgfile=$(tnspec spec get $specid.cfg -g sw)
        [[ ${#cfgfile} == 0 ]] && unset cfgfile
        bctfile=$(tnspec spec get $specid.bct -g sw)
        [[ ${#bctfile} == 0 ]] && unset bctfile
        if [[ $_fused -eq 1 ]]; then
            rcmbctfile=$(tnspec spec get $specid.rcm_bct -g sw)
            [[ ${#rcmbctfile} == 0 ]] && unset rcmbctfile
            pr_ok "RCM mode uses BCT file: $rcmbctfile"
        else
            unset rcmbctfile
        fi
        dtbfile=$(tnspec spec get $specid.dtb -g sw)
        [[ ${#dtbfile} == 0 ]] && unset dtbfile
        preboot=$(tnspec spec get $specid.preboot -g sw)
        bootpack=$(tnspec spec get $specid.bootpack -g sw)
        sku=$(tnspec spec get $specid.sku -g sw)
        [[ ${#sku} > 0 ]] && skuid=$sku
        odm=$(tnspec spec get $specid.odm -g sw)
        [[ ${#odm} > 0 ]] && odmdata=$odm
        _minbatt=$(tnspec spec get $specid.minbatt -g sw)
        _nodisp=$(tnspec spec get $specid.no_disp -g sw)
    fi
    pr_ok "OK!" "TNSPEC: "
    pr_info ""
}

# Do not integrate this to new tools, just use the xml updated filed in tnspec.json
signed_bin() {
    FOSTER_PRO_FUSE="p2571-0030"
    FOSTER_BASE_FUSE="p2571-2500"
    DARCY_FUSE="p2897-2500"
    b=$1
    sufix=""
    signedbits=("cboot.bin.signed" "nvtboot.bin.signed" "nvtboot_cpu.bin.signed" "tos.img.signed"\
            "warmboot.bin.signed" "rcm_1_signed.rcm")

    if [[ $b == *"$FOSTER_PRO_FUSE"* ]]; then
        sufix=".foster"
    elif [[ $b == *"$FOSTER_BASE_FUSE"* ]]; then
        sufix=".foster"
    elif [[ $b == *"$DARCY_FUSE"* ]]; then
        sufix=".darcy"
    fi

    if [[ ! -z $sufix ]]; then
      for i in ${signedbits[@]}; do
#            if [[ -a $PRODUCT_OUT/$i ]]; then
#                rm $PRODUCT_OUT/$i
#            fi
            #File must be there, otherwise build is broken so no check.
            cp $PRODUCT_OUT/$i$sufix $PRODUCT_OUT/$i
      done
    fi
}

# Automatically detect HW type and generate NCT if necessary
tnspec_auto() {
    local nctbin=$1
    pr_warn "Detecting board type...." "TNSPEC: " >&2
    pr_info "- if this takes more than 10 seconds, put the device into recovery mode" "TNSPEC: " >&2
    pr_info "  and choose from the HW list instead of \"auto\"." "TNSPEC: " >&2
    # Check if NCT partition exists first
    _download_NCT $nctbin 2> $TNSPEC_OUTPUT >&2
    if [ $? == 0 ]; then
        # Dump NCT partion
        pr_info "NCT Found. Checking SPEC..."  "TNSPEC: ">&2

        local hwid=$(tnspec nct dump spec -n $nctbin | _tnspec spec get id -g hw)
        if [ -z "$hwid" ]; then
            pr_err "NCT's spec partition or 'id' is missing in NCT." "TNSPEC: " >&2
            pr_warn "Dumping NCT..." "TNSPEC: " >&2
            tnspec nct dump -n $nctbin >&2
            return 1
        fi
        pr_info "SPEC found. Retrieving SW specid.." "TNSPEC: " >&2
        if [ ! -z "$hwid" ]; then
            local config=$(tnspec nct dump spec -n $nctbin | _tnspec spec get config -g hw)
            config=${config:-default}
            local spec_id=$hwid.$config

            pr_ok "SW Spec ID: $spec_id" "TNSPEC: " >&2
            pr_info "Check if NCT needs to be updated.." "TNSPEC: " >&2

            # Update NCT from SW specs. (SW shouldn't touch HW spec)
            tnspec nct update $spec_id -o ${nctbin}_update -n $nctbin -g sw
            if [ $? != 0 ]; then
                pr_err "tnspec tool had an error." "TNSPEC: " >&2
                return 1
            fi

            _su diff -b ${nctbin}_update $nctbin 2> $TNSPEC_OUTPUT >&2
            if [ $? != 0 ]; then
                pr_warn "NCT needs to be updated. Differences are:" "TNSPEC: " >&2
                tnspec nct dump -n $nctbin > ${nctbin}_diff_old
                tnspec nct dump -n ${nctbin}_update > ${nctbin}_diff_new

                # print difference between old and new version
                diff -u ${nctbin}_diff_old ${nctbin}_diff_new >&2

                rm  ${nctbin}_diff_old ${nctbin}_diff_new

                pr_info "Updating NCT" "TNSPEC: " >&2

                _update_NCT ${nctbin}_update
                pr_ok "Done updating NCT" "TNSPEC: ">&2
            else
                pr_warn "Nothing to update for NCT. Printing NCT." "TNSPEC: ">&2
                tnspec nct dump -n $nctbin >&2
            fi

            # HACK - put the device into recovery mode since we don't have a
            # resume mode working with tegraflash.
            [ "$flash_driver" == "tegraflash" ] && {
                echo "$(nvbin tegradevflash) --reboot recovery" 2> $TNSPEC_OUTPUT >&2
                $(nvbin tegradevflash) --reboot recovery 2> $TNSPEC_OUTPUT >&2
            }
            _su mv ${nctbin}_update $nctbin
            echo $spec_id
            return 0
        fi
    fi
    return 1
}

tnspec_manual() {
    local nctbin=$1
    local hwid=$(tnspec spec get $board.id -g hw)
    if [ -z $hwid ]; then
        pr_err "Couldn't find 'id' field from HW Spec '$board'." "TNSPEC: " >&2
        pr_warn "Dumping HW Spec '$board'." "TNSPEC: " >&2
        tnspec spec get $board -g hw >&2
        return 1
    fi
    local config=$(tnspec spec get $board.config -g hw)
    config=${config:-default}
    local spec_id=$hwid.$config

    _su rm $nctbin 2> $TNSPEC_OUTPUT >&2
    tnspec nct new $board -o $nctbin

    echo $spec_id
}

# download NCT
_download_NCT() {
    [ "$flash_driver" == "tegraflash" ] && {
        _download_NCT_X $@
        return $?
    }
    local x

    local partinfo=$PRODUCT_OUT/.nvflash_partinfo
    local nctbin=$1

    # generated directly by nvflash
    _su rm $partinfo $nctbin 2> $TNSPEC_OUTPUT >&2

    # download partition table
    _nvflash --getpartitiontable $(_os_path $partinfo) 2> $TNSPEC_OUTPUT >&2

    if [ $? != 0 ]; then
        pr_err "Failed to download partition table" "TNSPEC: " >&2
        return 1
    fi
    # cid for future use

    x=$(grep NCT $partinfo)
    _su rm $partinfo

    if [ -z "$x" ]; then
       pr_err "No NCT partition found" "TNSPEC: " >&2
       return 1
    fi

    _nvflash --read NCT $(_os_path $nctbin) 2> $TNSPEC_OUTPUT >&2
    if [ $? != 0 ];then
        pr_err "Failed to download NCT" "TNSPEC: " >&2
        return 1
    fi
    # do not delete $nctbin
    return 0
}

# tegraflash version (to be cleaned up)
_download_NCT_X() {
    local nctbin=$1
    local cid

    # generated directly by nvflash
    _su rm $nctbin 2> $TNSPEC_OUTPUT >&2

    cid=$($(nvbin tegrarcm) --uid | grep UID | cut -d' ' -f4)

    local _cmd="read NCT $nctbin"
    (cd $PRODUCT_OUT && $(nvbin tegraflash.py) --skipuid $flash_params --cmd "$_cmd")

    if [ $? != 0 ] || ! tnspec nct dump -n $nctbin 2> $TNSPEC_OUTPUT >&2; then
       pr_err "Failed to download NCT" "TNSPEC: " >&2
       return 1
    fi

    # do not delete $nctbin
    return 0
}

# Update NCT
_update_NCT() {
    [ "$flash_driver" == "tegraflash" ] && {
        _update_NCT_X $@
        return
    }
    local nctbin=$1
    _nvflash --download NCT $(_os_path $nctbin) 2> $TNSPEC_OUTPUT >&2
    return
}

# tegraflash version (to be cleaned up)
_update_NCT_X() {
    local nctbin=$1
    local _cmd="write NCT $nctbin"
    (cd $PRODUCT_OUT && $(nvbin tegraflash.py) $flash_params --cmd "$_cmd") 2> $TNSPEC_OUTPUT >&2
}

# tnspec w/o spec
_tnspec() {
    $tnspec_bin $@
}

# tnspec wrapper
tnspec() {
    local tnspec_spec=$PRODUCT_OUT/tnspec.json
    local tnspec_spec_public=$PRODUCT_OUT/tnspec-public.json

    if [ ! -f $tnspec_spec ]; then
        if [ ! -f $tnspec_spec_public ]; then
            pr_err "Error: tnspec.json doesn't exist." "TNSPEC: " >&2
            return
        fi
        tnspec_spec=$tnspec_spec_public
    fi

    _tnspec $@ -s $tnspec_spec
}

###############################################################################
# TNSPEC Platform Handler (NEW/EXPERIMENTAL)
# --------------------------------------
# TO SUPPORT:
# - Supports auto for T210
# - Flash tool agnostic
# - Makes use of chip id to retrieve/register board information
###############################################################################
tnspec_main() {
    # If BOARD is set, fall back to the legacy tnspec handler
    if [[ -n $board ]]; then
        [ "$board" == "auto" ] || {
            pr_err "\$BOARD ($BOARD) should not be set when -X option is used." "TNSPEC: "
            eval $product
            return
        }
    fi

    # main flash binary
    flash_driver=tegraflash

    # Initialization (sets cid)
    tnspec_init
}

tnspec_init() {
    if [ "$flash_driver" == "tegraflash" ]; then
        # tegracrcm probably won't work properly with the sanity package
        # without PATH set.
        cid=$($(nvbin tegrarcm) --uid | grep CID | cut -d' ' -f4)
    else
        pr_err "\$flash_driver is not supported" "TNSPEC: " >&2
    fi
}

###############################################################################
# Setup functions per target board
###############################################################################

# XXX: temporary function to update the flash target
_tnspec_switch_target_tegraflash() {
    ! _shell_is_interactive && {
        pr_err "-S is supported in interactive mode only."
        usage
        exit 1
    }
    [[ -n $_fused ]] && {
        pr_err "-S can't be used with -f (fused) option."
        usage
        exit 1
    }

    pr_err "***************************************" "board recovery: "
    pr_err "*** TEMPORARY FUNCTION TO WAR A BUG ***" "board recovery: "
    pr_err "*** ONLY SUPPORTED FOR T210 DEVICES ***" "board recovery: "
    pr_err "*** SOON TO BE DEPRECATED           ***" "board recovery: "
    pr_err "***************************************" "board recovery: "

    # XXX: HACK HACK HACK
    TNSPEC_OUTPUT=${TNSPEC_OUTPUT:-/dev/null}
    flash_driver=tegraflash
    nctrcv=$PRODUCT_OUT/nct_recovery.bin
    flash_params="--chip 0x21 --bl cboot.bin --applet nvtboot_recovery.bin"

    pr_warn "Detecting BOARD..." "board recovery: "

    _su rm $nctrcv 2> $TNSPEC_OUTPUT >&2
    _download_NCT $nctrcv 2> $TNSPEC_OUTPUT >&2
    if [ $? == 0 ]; then
        pr_ok "Found!" "board recovery: "
        local hwid=$(tnspec nct dump spec -n $nctrcv | _tnspec spec get id -g hw)
        local config=$(tnspec nct dump spec -n $nctrcv | _tnspec spec get config -g hw)
        config=${config:-default}
        local spec_id=$hwid.$config
        pr_info "------------- Current TNSPEC -------------"
        pr_info_b "       $spec_id"
        pr_info "------------------------------------------"
        pr_info ""
        pr_info_b "PLEASE CHOOSE A NEW TARGET" "board recovery: "
        pr_info ""

    else
        _cl="1;4;" pr_err    "SOMETHING WENT WRONG."
        pr_info   ""
        _cl="4;"   pr_info__ "Run it again with TNSPEC_OUTPUT=/dev/stderr. (in recovery mode):"
        pr_info   "e.g. "
        pr_info_b "$ TNSPEC_OUTPUT=/dev/stderr ./flash.sh -S"
        pr_info   ""
        exit 1
    fi

    local boards=$(tnspec spec list all -g hw)
    tnspec spec list -v -g hw
    pr_info ""
    pr_info_b "'help' - usage, 'list' - list frequently used, 'all' - list all supported"
    _choose "SELECT NEW TARGET >> " "$boards" board

    local _sn=$(tnspec nct dump serial -n $nctrcv)
    if [[ -z "$_sn" ]]; then
        pr_err "SERIAL NUMBER NOT FOUND." "board recovery: " >&2
        # Ask for the new serial number
        read -e -p "PLEASE ENTER SERIAL NUMBER >> " _sn
    fi

    rm $nctrcv.new 2> $TNSPEC_OUTPUT >&2
    local spec_id_new=$(TNSPEC_SET=sn=$_sn tnspec_manual $nctrcv.new)
    if [ -z $spec_id_new ]; then
        pr_err "Couldn't find SW Spec ID. Spec needs to be updated." "board recovery: ">&2
        exit 1
    fi
    pr_ok   "New NCT generated." "board recovery: "
    _tnspec nct dump -n $nctrcv.new
    pr_info ""
    pr_info "----------------- NEW TNSPEC --------------"
    pr_info_b "       $spec_id_new"
    pr_info "-------------------------------------------"
    pr_info ""
    pr_warn "(HACK) Updating NCT before flashing due to a bug that blindly backs up and resotres the NC partition" "board recovery: "
    _update_NCT $nctrcv.new
    if [ $? != 0 ]; then
        pr_err "(HACK) NCT update failed" "board recovery: "
        exit 1
    fi
    pr_ok "(HACK) NCT updated." "board recovery: "

    pr_info "Continues to a normal flashing flow. (Ignore the empty \"sn\" below)" "board recovery: "

    [ "$flash_driver" == "tegraflash" ] && {
        echo "$(nvbin tegradevflash) --reboot recovery" 2> $TNSPEC_OUTPUT >&2
        $(nvbin tegradevflash) --reboot recovery 2> $TNSPEC_OUTPUT >&2
    }
}

tnspec_generic() {
    # This is currently broken.
    # family=$(cat $PRODUCT_OUT/tnspec.json | _tnspec spec get family -g sw)
    family="Flat Package"
    tnspec_platforms "$family"
}

t132() {
    if [[ -z $board ]] && ! _shell_is_interactive; then
        board=norrin
    fi

    tnspec_platforms "Loki/TegraNote/T132"
}

t210() {
    flash_driver=tegraflash
    flash_params="--chip 0x21 --bl cboot.bin --applet nvtboot_recovery.bin"

    if [[ -z $board ]] && ! _shell_is_interactive; then
        board=t210
    fi

    # TEMPROARY BIG FAT WARNING
    [[ -z $_switch_target ]] && {
        pr_warn "********************************************************" "WARNING: "
        pr_warn "***                                                  ***" "WARNING: "
        pr_warn "***   YOU NEED TO USE '-S' OPTION TO SWITCH TARGET   ***" "WARNING: "
        pr_warn "***   (flash -S or ./flash.sh -S)                    ***" "WARNING: "
        pr_warn "***                                                  ***" "WARNING: "
        pr_warn "***                   OR                             ***" "WARNING: "
        pr_warn "***                                                  ***" "WARNING: "
        pr_warn "***   SELECT 'auto'                                  ***" "WARNING: "
        pr_warn "***                                                  ***" "WARNING: "
        pr_warn "********************************************************" "WARNING: "
    }

    tnspec_platforms "T210"
}

ardbeg() {
    # 'shield_ers' seems to be assumed in automation testing.
    # if $board is empty and shell is not interactive, set 'shield_ers' to $board
    if [ -z $board ] && ! _shell_is_interactive; then
       board=shield_ers
    fi

    tnspec_platforms "TegraNote/Ardbeg"
}

loki() {
    # 'loki_nff_b00' seems to be assumed in automation testing.
    # if $board is empty and shell is not interactive, set 'loki_nff_b00' to $board
    if [ -z $board ] && ! _shell_is_interactive; then
       board=loki_nff_b00
    fi

    tnspec_platforms "Loki/T124"
}

p1859() {
    # if $board is empty and shell is not interactive, set 'p1859' to $board
    if [ -z $board ] && ! _shell_is_interactive; then
       board=p1859
    fi

    tnspec_platforms "P1859/Automotive"
}

p1889() {
    # if $board is empty and shell is not interactive, set 'p1889' to $board
    if [ -z $board ] && ! _shell_is_interactive; then
       board=p1889
    fi

    tnspec_platforms "P1889/Automotive"
}

###############################################################################
# Utility functions
###############################################################################

# Test if we have a connected output terminal
_shell_is_interactive() { tty -s ; return $? ; }

# Test if string ($1) is found in array ($2)
_in_array() {
    local hay needle=$1 ; shift
    for hay; do [[ $hay == $needle ]] && return 0 ; done
    return 1
}

_choose_hook() {
    input_hooked=""
    if [ "$1" == "help" ]; then
        usage
        _cl="1;4;" pr_ok "Available Commands:"
        pr_info_b "'help', 'all', 'list'"
    elif [ "$1" == "list" ]; then
        tnspec spec list -v -g hw
    elif [ "$1" == "all" ]; then
        tnspec spec list all -v -g hw
    elif [ "$1" == "" ]; then
        [[ -n $board_default ]] && {
            pr_warn "Trying the default \"$board_default\"" "TNSPEC: "
            input_hooked=$board_default
            query_hooked=">> "

            # board_default is used only once.
            board_default=""
            return 1
        } || pr_err "You need to enter something." "selection: "
    else
        return 1
    fi
    return 0
}

# Display prompt and loop until valid input is given
_choose() {
    _shell_is_interactive || { "error: _choose needs an interactive shell" ; exit 2 ; }
    local query="$1"                   # $1: Prompt text
    local -a choices=($2)              # $2: Valid input values
    local input=$3                     # $3: Variable name to store result in
    local selected=''
    while [[ -z $selected ]] ; do
        read -e -p "$query" input
        _choose_hook $input || {
            input=${input_hooked:-$input}
            query=${query_hooked:-$query}

            if ! _in_array "$input" "${choices[@]}"; then
                pr_err "'$input' is not a valid choice." "selection: "
                pr_warn "Try 'all' for all supported options." "selection: "
            else
                selected=$input
            fi
        }
    done
    eval "$3=$selected"
    # If predefined input is invalid, return error
    _in_array "$selected" "${choices[@]}"
}

# Update odmdata watchdog bits
_watchdog_odm() {
    local watchdog=$1
    case $watchdog in
        0)
            odmdata=$(printf "0x%x" $(( odmdata & ~(3 << 16) )))
            ;;
        [1,2,3])
            odmdata=$(printf "0x%x" $(( odmdata | $watchdog << 16 )))
            ;;
        *)
            pr_err "Invalid value for option -w. Choose from {0,1,2,3}"
            exit 1
    esac
}

# Update odmdata power supply bits
_battery_odm() {
    if [[ $1 -eq 1 ]]; then
        odmdata=$(printf "0x%x" $(( odmdata | 1 << 22 )))
    elif [[ $1 -eq 0 ]]; then
        odmdata=$(printf "0x%x" $(( odmdata & ~(1 << 22) )))
    else
        pr_err "Invalid value for option -b. Choose from {0,1}"
        exit 1
    fi
}

# Update odmdata regarding required modem:
# select through bits [7:3] of odmdata
# e.g max value is 0x1F
_mdm_odm() {
    if [[ $_modem ]]; then
        if [[ $_modem -lt 0x1F ]]; then
            # 1st get a default odmdata if not yet set
            odmdata=${_odmdata-${odmdata-"0x98000"}}
            # 2nd: disable modem
            disable_mdm=$(( ~(0x1F << 3) ))
            odmdata=$(( $odmdata & $disable_mdm ))
            # 3rd: select required modem
            odmdata=`printf "0x%x" $(( $odmdata | $(( $_modem << 3 )) ))`
        else
            pr_warn "Unknown modem reference [${_modem}]. Unchanged odmdata." "_mdm_odm: "
        fi
    fi
}

# Pretty prints ($2 - optional header)
pr_info() {
    if  _shell_is_interactive; then
        echo -e "\033[95m$2\033[0m\033[${_cl}37m$1\033[0m"
    else
        echo $2$1
    fi
}
pr_info_b() {
    _cl="1;" pr_info "$1" "$2"
}
pr_info__() {
    _cl="4;" pr_info "$1" "$2"
}
pr_ok() {
    if _shell_is_interactive; then
        echo -e "\033[95m$2\033[0m\033[${_cl}92m$1\033[0m"
    else
        echo $2$1
    fi
}
pr_ok_bl() {
    if  _shell_is_interactive; then
        echo -e "\033[95m$2\033[0m\033[${_cl}94m$1\033[0m"
    else
        echo $2$1
    fi
}
pr_warn() {
    if  _shell_is_interactive; then
        echo -e "\033[95m$2\033[0m\033[${_cl}93m$1\033[0m"
    else
        echo $2$1
    fi
}
pr_err() {
    if _shell_is_interactive; then
        echo -e "\033[95m$2\033[0m\033[${_cl}91m$1\033[0m"
    else
        echo $2$1
    fi
}

nvbin() {
    if [[ -n $_nosudo ]]; then
        echo "$HOST_BIN/$1"
    else
        echo "sudo $HOST_BIN/$1"
    fi
}

# sudo nvflash
_nvflash() {
    recovery=${recovery:---force_reset recovery 100}
    # always wait for the device to be in recovery mode
    echo "$(nvbin nvflash) --wait $blob $@ --bl $(_os_path $PRODUCT_OUT/$blbin) $recovery" 2> $TNSPEC_OUTPUT >&2

    # some devices need a settling delay
    sleep 1
    $(nvbin nvflash) --wait $blob $@ --bl $(_os_path $PRODUCT_OUT/$blbin) $recovery
}

# su
_su() {
    if [[ -n $_nosudo ]]; then
        $@
    else
        sudo $@
    fi
}

# get CID
_get_cid()
{
    local cid_output=$PRODUCT_OUT/.nvflash_cid
    local cid=''
    _nvflash > $cid_output
    if [ $? != 0 ]; then
        cat $cid_output
        pr_err "nvflash failed." >&2
        return 1
    fi
    cid=$(cat $cid_output | grep "BR_CID:" | cut -f 2 -d ' ')
    if [ -z $cid ]; then
        cid=$(cat $cid_output | grep "uid from" | cut -f 6 -d ' ')
    fi
    rm $cid_output
    echo $cid
}

# convert unix path to windows path
_os_path()
{
    if [ $OSTYPE == cygwin ]; then
        echo \'$(cygpath -w $1)\'
    else
        echo $1
    fi
}

# check if we have required tools
_check_tools()
{
    # system tools
    local tools=(python diff)
    local t missing=()
    for t in ${tools[@]}; do
        if ! $(which $t 2> /dev/null >&2); then
            missing+=("$t")
        fi
    done

    if [[ ${#missing[@]} > 0 ]]; then
        pr_warn "Missing tools: ${missing[*]}"
        if [ "$OSTYPE" == "cygwin" ]; then
            local cygbin=setup-$(uname -m).exe
            pr_info "You're using Cygwin. To install these missing tools, please download $cygbin"
            pr_info "from http://cygwin.com/$cygbin and run"
            pr_info ""
            pr_info "  >> $cygbin -q -P python,diffutils"
            pr_info ""
        fi
        return 1
    fi

    # NVIDIA flash tools
    if [ "$OSTYPE" == "cygwin" ]; then
        # XXX: This check is not sufficient. Needs to be fixed.
        local _x=$(which tegraflash.py 2> /dev/null)
        [ "$_x" == "" ] && {
            _x=$(which nvflash 2> /dev/null)
        }
        if [ -z "$_x" ]; then
            pr_err "Missing required flash binaries (tegraflash.py or nvflash)" "_check_tools: "
            exit 1
        fi
        HOST_BIN=$(dirname "$_x")
    else
        [ ! -x $HOST_BIN/tegraflash.py ] && [ ! -x $HOST_BIN/nvflash ] && {
            pr_err "Missing required flash binaries (tegraflash.py or nvflash)" "_check_tools: "
            exit 1
        }
    fi

    return 0
}

# Needed for fused devices, since they need to be flashed with secureflash
# command, rather than flash command
_change_flash_to_secure_flash() {
    local running_str=''

    # Partition strings at ;
    OLDIFS=$IFS; IFS=';'

    for i in $cmd; do
        stripped_val=$(echo -n $i | tr -d ' ')
        if [[ $stripped_val = 'flash' ]]; then # Change flash to secureflash
            running_str=${running_str}"secureflash;"
        else # Append as is
            running_str=${running_str}${i}";"
        fi
    done

    # Revert back the IFS, so that we set the cmd variable properly
    IFS=$OLDIFS

    cmd=$running_str
}

# Set all needed parameters
_set_cmdline_nvflash() {
    # Set modem in odmdata if required
    _mdm_odm

    # Minimum battery charge required.
    if [[ -n $_minbatt ]]; then
        pr_err "*** MINIMUM BATTERY CHARGE REQUIRED = $_minbatt% ***" "min_batt: "
        minbatt="--min_batt $_minbatt"
    fi

    # Disable display if specified (to prevent flashing failure due to low battery)
    if [[ "$_nodisp" == "true" ]]; then
        nodisp="--odm limitedpowermode"
        pr_warn "Display on target is disabled while flashing to save power." "no_disp: "
    fi

    # Set ODM data, BCT and CFG files (with fallback defaults)
    odmdata=${_odmdata-${odmdata-"0x9c000"}}
    bctfile=${bctfile-"bct.cfg"}
    cfgfile=${cfgfile-"flash.cfg"}

    # default variables
    blbin="bootloader.bin"

    # if flashing fused devices, lock bootloader. (bit 13)
    [[ -n $_fused ]] && {
        blob="--blob $(_os_path $PRODUCT_OUT/blob.bin)"
        blbin="bootloader_signed.bin"
        odmdata=$(printf "0x%x" $(( $odmdata | (( 1 << 13 )) )) )
    }

    # Set NCT option, defaults to empty
    nct=${nct-""}

    # Set SKU ID, MTS settings. default to empty
    skuid=${_skuid-${skuid-""}}
    [[ -n $skuid ]] && skuid="-s $skuid"
    preboot=${preboot-""}
    [[ -n $preboot ]] && preboot="--preboot $preboot"
    bootpack=${bootpack-""}
    [[ -n $bootpack ]] && bootpack="--bootpack $bootpack"

    # Update DTB filename if not previously set.
    # in mobile sanity testing (Bug 1439258)
    if [[ -z $dtbfile ]] && _shell_is_interactive; then
        dtbfile=$(grep dtb ${PRODUCT_OUT}/$cfgfile | cut -d "=" -f 2)
        pr_info "Using the default product dtb file $_dtbfile"
    else
        # Default used in automated sanity testing is "unknown"
        dtbfile=${dtbfile-"unknown"}
    fi
    cmdline=(
        $blob
        $minbatt
        --bct $bctfile
        --setbct
        --odmdata $odmdata
        --configfile $cfgfile
        --dtbfile $dtbfile
        --create
        --bl $blbin
        --wait
        $skuid
        $nct
        $nodisp
        $preboot
        $bootpack
        --go
    )

    cmdline=($(nvbin nvflash) ${cmdline[@]})

    # Add optional command-line arguments
    if [[ $_args ]]; then
        # This assumes '--go' is last in cmdline
        unset cmdline[${#cmdline[@]}-1]
        cmdline=(${cmdline[@]} ${_args[@]} --go)
    fi
}

# Set all needed parameters for Automotive boards.
_set_cmdline_automotive() {
    # Parse bootburn commandline
    burnflash_cmd=
    if [ -n "${skuid}" ]; then
        burnflash_cmd="$burnflash_cmd -S ${skuid}"
    fi

    if [ -n "${dtbfile}" ]; then
        burnflash_cmd="$burnflash_cmd -d ${dtbfile}"
    fi

    odmdata=${_odmdata-${odmdata}}
    if [ -n "${odmdata}" ]; then
        burnflash_cmd="$burnflash_cmd -o ${odmdata}"
    fi

    if [[ $_modem ]]; then
        if [[ $_modem -lt 0x1F ]]; then
            # Set odmdata in bootburn.sh
            burnflash_cmd="$burnflash_cmd -m ${_modem}"
        else
            pr_warn "Unknown modem reference [${_modem}]. Unchanged odmdata." "_mdm_odm: "
        fi
    fi

    cmdline=(
        $PRODUCT_OUT/bootburn.sh
        -a
        -r ram0
        -Z zlib
        $burnflash_cmd
        ${_args[@]}
    )
}

_sanity_backup_partitions() {
    local eks_file_name="EKS_bak.bin"
    if [ -e "${_parts_path}/eks_bak.bin" ]; then
        eks_file_name="eks_bak.bin"
    fi
    local stoadd="write FCT ${_parts_path}/fct_bak.bin; write NCT ${_parts_path}/nct_bak.bin; write EKS ${_parts_path}/$eks_file_name"
    local running_str=""

    # Partition strings at ;
    OLDIFS=$IFS; IFS=';'

    for i in $cmd; do
        stripped_val=$(echo -n $i | tr -d ' ')
        case $stripped_val in
            reboot*) running_str="${running_str}${stoadd};${i};" ;;
            write*) ;;
            read*) ;; #ignore read and write, only backup what's required
            *) running_str="${running_str}${i};" ;;
        esac
    done

    # Revert back the IFS, so that we set the cmd variable properly
    IFS=$OLDIFS

    cmd=$running_str
}

_write_uda_partition() {
    local running_str=""
    local write_uda_cmd=" write UDA userdata.img; "
    # Partition strings at ;
    OLDIFS=$IFS; IFS=';'

    for i in $cmd; do
        stripped_val=$(echo -n $i | tr -d ' ')
        case $stripped_val in
            *flash*) running_str="${running_str}${i};${write_uda_cmd}" ;;
            *\") running_str="${running_str}${i}" ;;
            *) running_str="${running_str}${i};" ;;
        esac
    done

    # Revert back the IFS, so that we set the cmd variable properly
    IFS=$OLDIFS

    cmd=$running_str
}

_set_cmdline_tegraflash() {
    pr_info "Using Tegraflash to flash cboot"

    blbin=$(tnspec spec get $specid.bl -g sw)
    signed_blbin=$(tnspec spec get $specid.signed_bl -g sw)
    chip=$(tnspec spec get $specid.chip -g sw)
    odmdata=$(tnspec spec get $specid.odm -g sw)
    applet=$(tnspec spec get $specid.applet -g sw)
    signed_applet=$(tnspec spec get $specid.signed_applet -g sw)
    key=$(tnspec spec get $specid.key -g sw)
    hostbin=$(tnspec spec get $specid.hostbin -g sw)
    out=$(tnspec spec get $specid.out -g sw)

    if [[ $_erase_all_partitions -eq 1 ]]; then
        # Donot bother about backing up partitions
        if [[ $_fused -eq 1 ]]; then
            cmd="secureflash; reboot"
        else
            cmd="flash; reboot"
        fi
    else
        # XXX: see if there's cmd for GVS
        if ! _shell_is_interactive; then
            cmd=$(tnspec spec get $specid.cmd_gvs -g sw)
        fi
        if [ -z "$cmd" ]; then
            cmd=$(tnspec spec get $specid.cmd -g sw)
        fi
        if [[ $_fused -eq 1 ]]; then
            # Hunt down flash; and replace with secureflash;
            _change_flash_to_secure_flash
        fi
    fi

    skuid=${_skuid-${skuid-""}}
    if [[ -n $skuid && -f $PRODUCT_OUT/fuse_bypass.xml && $_fused -ne 1 ]]; then
        cmd="parse fusebypass fuse_bypass.xml $skuid; $cmd"
        fbfile="--fb fuse_bypass.bin"
    fi
    if [ ! -z $key ]; then
        key="--key $key"
    fi

    # flash UDA for (1) GVS fused foster/darcy targets (2) all unfused boards
    # as UDA (userdata.img) contains files needed for GVS tests
    _write_uda=0
    if [[ -n $_fused ]]; then
        if [ "$BOARD" == "p2897-2500-dvt" ] || [ "$BOARD" == "p2571-0030-000" ]; then
            _write_uda=1
        fi
    else
        _write_uda=1
    fi

    if [[ $_parts -eq 1 ]]; then
        _sanity_backup_partitions
    fi

    if [ ! -z $hostbin ]; then
        hostbin="--hostbin $hostbin"
    fi
    if [ ! -z $out ]; then
        out="--out $out"
    fi
    if [[ -n $cmd ]]; then
        cmd="--cmd \"$cmd\""
    fi

    odmdata=${_odmdata-${odmdata-"0x9c000"}}

    # Odmdata bits for power supply need override
    if [[ -n $_battery ]]; then
        _battery_odm $_battery
    fi

    # Odmdata bits for wdt need override
    if [[ -n $_watchdog ]]; then
        _watchdog_odm $_watchdog
    fi

    if [[ $_fused -eq 1 ]]; then
        odmdata=$(printf "0x%x" $(( odmdata | 1 << 13 )))
    fi

    bctfile=${bctfile:-"bct_cboot.cfg"}
    if [[ $_fused -eq 1 ]]; then
        bctfile=${bctfile%.cfg}.bct #Rename extension for fused-signed images
    fi

    cfgfile=${cfgfile:-"flash.xml"}

    # For diags, append _diag.xml to file containing partition table
    if [[ $_diags -eq 1 ]]; then
        cfgfile=$(basename $cfgfile) # Get filename from absolute path
        cfgfile="${cfgfile%.xml}" # Strip off extension
        cfgfile=${cfgfile}_diag.xml # Add requisite suffix for diag
    fi

    if [[ $_fused -eq 1 ]]; then
        blbin=${signed_blbin:-"cboot.bin.signed"}
    else
        blbin=${blbin:-"cboot.bin"}
    fi

    chip=${chip:-"0x21"}

    if [[ $_fused -eq 1 ]]; then
        applet=${signed_applet:-"rcm_1_signed.rcm"}
    else
        applet=${applet:-"nvtboot_recovery.bin"}
    fi

    if [[ ! -z $dtbfile ]] ; then
        sed -i "/bpmp/!s/.*.dtb.*/            <filename> ${dtbfile} <\/filename>/" $PRODUCT_OUT/$cfgfile
        pr_warn "Updating dtb partition in $cfgfile. Note this will actually change the on-disk copy of partition table in $PRODUCT_OUT"
    fi

    if [[ $_write_uda -eq 1 ]]; then
        _write_uda_partition
    fi

    # Parse tegraflash commandline
    cmdline=(
        --bct $bctfile
        --bl  $blbin
        --cfg $cfgfile
        --odmdata $odmdata
        --bldtb $dtbfile
        --chip $chip
        --applet $applet
        --nct $(_os_path $nctbin)
        $key
        $hostbin
        $out
        $cmd
        $fbfile
        ${_args[@]}
        )

    if [[ ! -z $rcmbctfile ]]; then
        cmdline=($(nvbin tegraflash.py) --rcm_bct $rcmbctfile ${cmdline[@]})
    else
        cmdline=($(nvbin tegraflash.py) ${cmdline[@]})
    fi

    if [[ $_fused -eq 1 ]]; then
        cmdline=(${cmdline[@]} --securedev)
    fi
}

_set_cmdline() {
    if [ "$flash_app" == "tegraflash" ] || [ "$flash_driver" == "tegraflash" ]; then
        _set_cmdline_tegraflash

        # XXX: move this to _track_board
        # For t210+, check if host is linux.
        case $OSTYPE in
            linux*)
                local internal_url="http://tegraota-internal.nvidia.com/ota/verify_internal.html"
                local internal_url_check="verifiedasinternalotaserver"
        # Check if host is part of nvidia internal.
                local check_internal=$(wget -T 10 -qO- $internal_url 2>&1)
                if [ "x$check_internal" == "x$internal_url_check" ]; then
                    _track_board
                fi
                ;;
        esac
    elif [ "$flash_app" == "bootburn" ]; then
        # For Automotive boards.
        _set_cmdline_automotive
    else
        _set_cmdline_nvflash
    fi
}

_track_board() {
    [ "$_no_track" == "1" ] && return

    # track board code
    local server_addr1="http://mjansen-vista/BoardRework/Home/SendUpdate"
    local server_addr2="http://gsarode-devteg/track.php"
    local curl_args=()
    local board_info=$(tnspec nct dump board_info -n $nctbin)
    user=$USER

    local b_proc_id=$(echo $board_info | awk -v pattern="${module_type[0]}" '$1 ~ pattern {print $2}')
    local b_pmu_id=$(echo $board_info | awk -v pattern="${module_type[1]}" '$3 ~ pattern {print $4}')
    local b_disp_id=$(echo $board_info | awk -v pattern="${module_type[2]}" '$5 ~ pattern {print $6}')
    local serial=$(tnspec nct dump -n $nctbin | grep serial | awk ' {print $3} ')

    declare -A board_data
    board_data[Proc]=$b_proc_id; board_data[PMU]=$b_pmu_id; board_data[Disp]=$b_disp_id; board_data[Audio]=0
    board_data[Camera]=0; board_data[Sensor]=0; board_data[NFC]=0; board_data[Debug]=0; board_data[User]=$user

    ip_addr="$(ifconfig | /bin/grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | /bin/grep -Eo '([0-9]*\.){3}[0-9]*' | /bin/grep -v '127.0.0.1'| head -n 1)"
    local length=${#serial}
    local PSTDATE="$(TZ="America/Los_Angeles" date +%D)"
    local PSTTIME="$(TZ="America/Los_Angeles" date +%T)"
    cd $TOP/.repo/manifests
    local branch_id=$(git branch -r | grep -e '->' | awk ' {print $1} '| cut -d "/" -f 2)

    if [ "$length" -gt 13 ]; then
        local serial_n=${serial:0:13}

        # curl command for server_addr1
        curl_args+=("--silent --max-time 5 --data-urlencode 's={ ParentID: \"$serial_n\"")
        curl_args+=(", SystemIPAddress: \"$ip_addr\", Children: [")

        for k in "${!board_data[@]}"
        do
            curl_args+=("{ChildType: \"$k\", ChildID: \"${board_data[$k]}\"},")
        done
        curl_args+=("],UptimeSinceUpdate: 54,IsBoot : true,ForceRework : true}'")
        curl_args+=("$server_addr1 >/dev/null 2>&1 &")
        local curl="curl ${curl_args[@]}"
        eval $curl

        # curl command for server_addr2
        local c_command="curl --silent --max-time 5 --data-urlencode 's= $PSTDATE, $PSTTIME, $user, $ip_addr, $serial_n, $branch_id, $specid' $server_addr2 >/dev/null 2>&1 &"
        eval $c_command

    # if not valid serial number; send proc board id
    else
        local c_command2="curl --silent --max-time 5 --data-urlencode 's= $PSTDATE, $PSTTIME, $user, $ip_addr, , $branch_id, $specid' $server_addr2 >/dev/null 2>&1 &"
        eval $c_command2
        _invalidate_serial
    fi
}

_invalidate_serial() {
    # hook to update server if serial number is invalid
    local server_addr="http://gsarode-devteg/blacklist.php"

    local c_command="curl --silent --max-time 5 --data-urlencode 's= ,$user, $HOSTNAME, $ip_addr, $specid' $server_addr >/dev/null 2>&1 &"
    eval $c_command
}

###############################################################################
# Main code
###############################################################################

# convert args into an array
args_a=( "$@" )

# Optional arguments
while getopts "no:s:m:b:w:P:pfzhrdXNS" OPTION
do
    case $OPTION in
    h) usage
        exit 0
        ;;
    z) _diags=1; _erase_all_partitions=1;
        ;;
    d)  _dryrun=1;
        ;;
    r)  _remember_board=1;
        ;;
    f)  _fused=1;
        ;;
    m) _modem=${OPTARG};
        ;;
    n) _nosudo=1;
        ;;
    o) _odmdata=${OPTARG};
        ;;
    s) _skuid=${OPTARG};
        _peek=${args_a[(( OPTIND - 1 ))]}
        if [ "$_peek" == "forcebypass" ]; then
            _skuid="$_skuid $_peek"
            shift
        fi
        ;;
    p)  fhome=$(eval echo ~${HOME});
        pdir=".partsback"
        _parts_path="${HOME}/${pdir}"
        _parts=1
        ;;
    P)  _parts_path=${OPTARG};
        _parts=1
        ;;
    b) _battery=${OPTARG};
        ;;
    w) _watchdog=${OPTARG};
        ;;
    e) _erase_all_partitions=1;
        ;;
    X) _exp=1;
        ;;
    N) _no_track=1;
        ;;
    # TEMPORARY
    S) _switch_target=1;
        ;;
    esac
done

# FIXME: we shouldn't rely on the path name to choose the main flash handler
if [[ -z $PRODUCT_OUT ]]; then
    PRODUCT_OUT=.
    product=tnspec_generic

    # don't track for "flat packages"
    _no_track=1
else
    product=$(echo ${PRODUCT_OUT%/} | sed -e 's#.*\/\(.*\)#\1#' -e 's#_\(int\|gen\|64\)$##')
    case $product in
        shieldtablet)
            product=ardbeg
            ;;
        *)
            ;;
    esac
fi

HOST_BIN=${HOST_BIN:-.}

if [[ ! -d ${PRODUCT_OUT} ]]; then
    pr_err "\"${PRODUCT_OUT}\" is not a directory" "flash.sh: "
    usage
    exit 1
fi

tnspec_bin=$PRODUCT_OUT/tnspec_legacy.py

if [ ! -x $tnspec_bin ]; then
    pr_err "Error: $tnspec_bin doesn't exist or is not executable." "TNSPEC: " >&2
    exit 1
fi

if ! _check_tools; then
    pr_err "Error: missing required tools." "flash.sh: " >&2
    exit 1
fi

# Detect OS
case $OSTYPE in
    cygwin)
        _nosudo=1
        ;;
    linux*)
        ;;
    *)
        pr_err "unsupported OS type $OSTYPE detected" "flash.sh: "
        exit 1
        ;;
esac

# Optional command-line arguments, added to nvflash cmdline as-is:
# flash -b my_flash.bct -- <args to nvflash>
shift $(($OPTIND - 1))
_args=$@

# If BOARD is set, use it as predefined board name
[[ -n $BOARD ]] && board="$BOARD"

[[ -n $_switch_target ]] && _tnspec_switch_target_tegraflash

[[ -n $_fused ]] && {
    pr_err "[Flashing FUSED devices]" "fused: "
}

# Run product function to set needed parameters
[[ -n $_exp ]] && tnspec_main || eval $product

_set_cmdline

pr_info_b "====================================================================="
pr_info__ "PRODUCT_OUT"
echo "$PRODUCT_OUT"
pr_info ""
pr_info__ "FLASH COMMAND (Run from $PRODUCT_OUT)"
echo "${cmdline[*]}"
pr_info_b "====================================================================="

# exit if dryrun is set
[[ -n $_dryrun ]] && exit 0

pr_ok "Flashing..." "flash.sh: "
# Execute command
(cd $PRODUCT_OUT && eval ${cmdline[@]})
ret=$?
wait
exit $ret
