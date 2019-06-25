#!/bin/bash
#
# Copyright (c) 2013-2018, NVIDIA CORPORATION.  All rights reserved.
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
    pr_info   "flash.sh [-h] [-n] [-o <odmdata>] [-s <skuid> [forcebypass]]" "$_margin"
    pr_info   "         [-d] [-N] [-u] [-v] [-O] [-F] [-C]" "$_margin"
    pr_info   "         [-f] [-i <USB instance>] [-- [optional args]]" "$_margin"

    pr_info_b "-h" "$_margin"
    pr_info   "  Prints help " "$_margin"
    pr_info_b "-n" "$_margin"
    pr_info   "  Skips using sudo on cmdline" "$_margin"
    pr_info_b "-o" "$_margin"
    pr_info   "  Specify ODM data to use" "$_margin"
    pr_info_b "-s" "$_margin"
    pr_info   "  Specify SKU to use, with optional forcebypass flag to nvflash" "$_margin"
    pr_info_b "-f [NVFLASH ONLY]" "$_margin"
    pr_info   "  For fused devices. uses blob.bin and bootloader_signed.bin when specified." "$_margin"
    pr_info_b "-d" "$_margin"
    pr_info   "  Dry-run. Exits after printing out the final flash command" "$_margin"
    pr_info_b "-i" "$_margin"
    pr_info   "  USB instance" "$_margin"
    pr_info_b "-u" "$_margin"
    pr_info   "  Unattended/Silent mode. (\"No questions asked.\")" "$_margin"
    pr_info_b "-v" "$_margin"
    pr_info   "  Verbose mode" "$_margin"
    pr_info_b "-F" "$_margin"
    pr_info   "  Ignores errors." "$_margin"
    pr_info_b "-C" "$_margin"
    pr_info   "  Do not color output" "$_margin"
    pr_info_b "-O" "$_margin"
    pr_info   "  Offline Mode." "$_margin"
    pr_info_b "-N" "$_margin"
    pr_info   "  Don't track. Disables board tracking." "$_margin"
    pr_info   ""
    pr_info__ "Environment Variables:" "$_margin"
    pr_info   "PRODUCT_OUT     - target build output files (default: $ROOT_PATH)" "$_margin"
    [ -n "${PRODUCT_OUT}" ] &&
    pr_warn   "                      \"${PRODUCT_OUT}\" $_margin" ||
    pr_err    "                  Currently Not Set!" "$_margin"
    pr_info   "HOST_BIN        - path to flash executable (default: $ROOT_PATH)" "$_margin"
    [ -n "${HOST_BIN}" ] &&
    pr_warn   "                      \"${HOST_BIN}\" $_margin" ||
    pr_err    "                  Currently Not Set!" "$_margin"
    pr_info   "BOARD           - Select board without a prompt. (default: None)" "$_margin"
    [ -n "${BOARD}" ] &&
    pr_warn   "                      \"${BOARD}\" $_margin" ||
    pr_err    "                  Currently Not Set!" "$_margin"
    pr_info   "TNSPEC_ID       - Select TNSPEC without a prompt. (default: None)" "$_margin"
    [ -n "${TNSPEC_ID}" ] &&
    pr_warn   "                      \"${TNSPEC_ID}\" $_margin" ||
    pr_err    "                  Currently Not Set!" "$_margin"
    pr_info   "OVERRIDE_CONFIG - Select SW configuration without a prompt. (default: None)" "$_margin"
    [ -n "${OVERRIDE_CONFIG}" ] &&
    pr_warn   "                      \"${OVERRIDE_CONFIG}\" $_margin" ||
    pr_err    "                  Currently Not Set!" "$_margin"
    pr_info   "NOCOLOR         - Do not color output if set" "$_margin"
    [ -n "${NOCOLOR}" ] &&
    pr_warn   "                  Current Set" "$_margin" ||
    pr_err    "                  Currently Not Set!" "$_margin"
    pr_info   ""
}

# Help message to print when we couldn't retrieve an object
help_missing_obj() {
    [ -z "$_force" ] && {
    pr_info ""
    _cl="1;4;" \
    pr_info "DEVICE RESOURCES NOT FOUND"
    [ -n "$1" ] && pr_info "" && pr_warn  "[Missing $1]"
    pr_info ""
    [ "$tns_online" != "1" ] && {
        pr_info "TNSPEC Server is offline."
        pr_info "Please try again in a few minutes OR use '-F' option to ignore missing resources."
    } || {
        pr_info "You're seeing this because resources registered for this device were not found."
        pr_info "While this not common, you have 3 options."
        pr_info ""
        pr_info "   1) File a bug for missing resources with OBJ keys."
        pr_info ""
        pr_info "   2) 'flash register' to upload resources from your device."
        pr_info "       Use this option if you know your device has correct resources."
        pr_info ""
        pr_info "   3) Flash with '-F' option to ignore missing resources."
        pr_info ""
    }
    exit 1
    }
}

###############################################################################
# TNSPEC Platform Handler
###############################################################################

#
# tnspec_setup nct source [args]
# - Sets up platform data using various sources.
#
# This is the main platform handler where the final TNSPEC (NCT) gets generated.
#
# Following sources are supported:
#   o tnspec          - path to the tnspec file
#   o auto            - use the tnspec from the device
#   o manual [method] - switch SKU from compatible HW list. 'method' is used to
#                       use an alternate flashing method if availble.
#   o board  [target] - builds TNSPEC based on the flash 'target'
#
tnspec_setup()
{
    specid=''
    local tnsbin="$1"
    local src="$2"
    local arg="$3"

    [ -z "$tnsbin" ] && {
        pr_err "tnsbin must be specified." "tnspec_setup: "
        exit 1
    }

    [ -e "$tnsbin" ] && [ ! -w "$tnsbin" ] && _su rm $tnsbin

    case $src in
       tnspec)
           tnspec_setup_tnspec $tnsbin $arg ;;
       auto)
           tnspec_setup_auto $tnsbin $arg ;;
       manual)
           tnspec_setup_manual $tnsbin $arg ;;
       board)
           tnspec_setup_board $tnsbin $arg ;;
       *)
           pr_err "Unsupported source [$src]" "tnspec_setup: " ;;

    esac
    pr_info "NCT created." "tnspec_setup: "

    if [ "$flash_interface" == "legacy" ]; then
        tnspec nct dump -n $tnsbin
        tnspec_get_sw_variables
        pr_ok "OK!" "tnspec_setup: "
        return
    fi

    local sw_specs=$(tnspec spec list all -g sw)
    if ! _in_array $specid $sw_specs; then
        pr_warn "TNSPEC ID '$specid' is not supported. Please file a bug." "tnspec_setup: "
        exit 1
    fi

    if [ "$origin" == "factory" ] || [ "$(getprop arg_secure)" != "--securedev" ] || [ "${cur_specid##*.}" == "diag" ]; then
        pr_info "Check if NCT needs to be updated from SW" "tnspec_setup: "
        nct_update_hw_override $tnsbin $tnsbin.updated $specid
        nct_diff $tnsbin $tnsbin.updated &&
            pr_info_b "[hw_override] TNSPEC unchanged." "tnspec_setup: " ||
            { cp $tnsbin.updated $tnsbin; pr_warn "TNSPEC has been updated." "tnspec_setup: "; }

        pr_info "See if we need to update TNSPEC from BOARD_UPDATE" "tnspec_setup: "
        nct_update $tnsbin $tnsbin.updated VAR BOARD_UPDATE
        nct_diff $tnsbin $tnsbin.updated &&
            pr_info_b "[BOARD_UPDATE] Nothing to update." "tnspec_setup: " ||
            { cp $tnsbin.updated $tnsbin; pr_warn "TNSPEC has been updated." "tnspec_setup: "; }
    fi

    tnspec_preload $specid
    tnspec_get_sw_variables

    pr_ok "OK!" "tnspec_setup: "
}

#
# tnspec_setup_tnspec nct tnspec_path
# - Sets up NCT from a tnspec file specified
#
# [env]
# specid
# - sets TNSPEC ID to 'specid'
#
tnspec_setup_tnspec() {
    local tnsbin="$1"
    local src="$2"

    [ ! -f "$src" ] && {
        pr_err "'$src' doesn't exist." "tnspec_setup_tnspec: "
        exit 1
    }
    _tnspec nct new -o $tnsbin < $src
    specid="$(_tnspec spec get id < $src).$(_tnspec spec get config < $src)"
}

#
# tnspec_setup_board nct flash_target
# - Sets up NCT using flash target
#
# [env]
# specid
# - sets TNSPEC ID to 'specid'
#
tnspec_setup_board() {
    local tnsbin="$1"
    local target="$2"

    local boards=$(tnspec spec list all -g hw)
    ! _in_array "$target" $boards && {
        pr_err "HW Spec ID '$target' is not supported." "tnspec_setup_board: "
        exit 1
    }

    local hwid=$(tnspec spec get $target.id -g hw)
    if [ -z "$hwid" ]; then
        pr_err "Couldn't find 'id' field from HW Spec '$target'." "tnspec_setup_board: " >&2
        pr_warn "Dumping HW Spec '$target'." "tnspec_setup_board: " >&2
        tnspec spec get $target -g hw >&2
        exit 1
    fi

    local config=${tnspecid_config_override:-$(tnspec spec get $target.config -g hw)}
    config=${config:-default}
    specid=$hwid.$config

    if [ -z "$specid" ]; then
        pr_err "Couldn't find TNSPEC ID '$specid'. Spec needs to be updated." "tnspec_setup_board: ">&2
        exit 1
    fi

    tnspec nct new $target -o $tnsbin

    # Update config field if tnspecid_config_override is set
    [ -n "$tnspecid_config_override" ] && {
        nct_update $tnsbin $tnsbin.updated VAL "config=$config"
        nct_diff $tnsbin $tnsbin.updated || cp $tnsbin.updated $tnsbin
    }
}

#
# tnspec_setup_auto nct
# - Sets up NCT using TNSPEC from device
#
# [env]
# specid
# - sets TNSPEC ID to 'specid'
#
tnspec_setup_auto() {
    local tnsbin="$1"
    local method="$2"
    tnspec_detect_hw $tnsbin
    tnspec_preload $specid

    [ "$flash_interface" == "legacy" ] && return

    # Use an alternate method if specified
    [ -n "$method" ] && {
        local alt_methods="$(tnspec_get_sw $specid.alt_methods)"
        _in_array $method $alt_methods && {
            pr_info_b "··················································"
            pr_info   ""
            pr_cyan   "     USING '$method' FLASHING METHOD"
            pr_info   ""
            pr_info_b "··················································"
            flash_method=$method
        } || {
            pr_err "Alternate flashing method '$method' is not supported." \
                   "tnspec_setup_auto: "
            pr_info__ "Supported Flashing Methods:"
            pr_info "$alt_methods"
            exit 1
        }
    }
}

#
# tnspec_setup_manual nct [method]
# - Sets up NCT using TNSPEC from device
#
# 'manual' allows users to switch to a different SKU as long as they shared the
# same HW ID which is the first part of TNSPEC ID. Additionally, 'method' can
# be passed to choose alternate flashing methods if supported.
#
# [env]
# specid
# - sets TNSPEC ID to 'specid'
#
# [args]
# method
# - if set, it will use alternate methods for flashing.
#
tnspec_setup_manual() {
    local tnsbin="$1"
    local method="$2"

    # Detect HW
    tnspec_detect_hw $tnsbin

    [ "$_unattended" == "1" ] && [ -z "$TNSPEC_ID" ] && [ -z "$OVERRIDE_CONFIG" ] && {
        pr_err "TNSPEC_ID must be set for unattended mode." "tnspec_setup_manual: "
        exit 1
    }

    local hwid=$(_tnspec nct dump tnspec -n $tnsbin | _tnspec spec get id)
    local hwconfig=$(_tnspec nct dump tnspec -n $tnsbin | _tnspec spec get config)
    local _sw_specs=$(tnspec spec list $hwid -g sw)

    # secure fused device not allow hw change
    if [ "$(getprop arg_secure)" == "--securedev" ] && [ "$hwconfig" != "diag" ]; then
        _sw_specs=$(tnspec spec list $hwid.$hwconfig -g sw)
    fi

    # Check tnspec with alternate flashing methods
    declare -A alt_methods
    local tns m
    for tns in $_sw_specs; do
        tnspec_preload $tns
        for m in $(tnspec_get_sw $tns.alt_methods)
        do
            # Save off supported tnspecs per method
            alt_methods[$m]="${alt_methods[$m]}$tns "
        done
    done

    # Save methods
    local methods="${!alt_methods[*]}"
    [ -n "$method" ] && {
        _in_array $method $methods || {
            pr_err_b "Alternate method '$method' is not supported for this HW." "manual: "
            [ "$_unattended" == "1" ] && exit 1
            pr_warn "Ignoring '$method'" "manual: "
            pr_info_b "··················································"
            method=""
        }
    }

    [ -z "$method" ] && [ -n "$methods" ] && {
        pr_info_b "··················································"
        pr_info_b "FOLLOWING ALTERNATE FLASHING METHODS ARE AVAILABLE"
        pr_cyan   "$methods"
        pr_info   ""
        pr_info   "   To select a method, type 'method <method>'"
        pr_info_b "     e.g. >> method $m"
        pr_info   "   To reset, type 'method'"
        pr_info_b "     e.g. $m >> method"
        pr_info   ""
        for m in $methods; do
            pr_info_b "$m" "▸ "
            # Print description if available
            tnspec_preload $hwid
            local alt_desc="$(tnspec_get_sw $hwid.default.alt_methods_descs.$m)"
            [ -n "$alt_desc" ] &&
                pr_warn "▮ $alt_desc" "  "
            for tns in ${alt_methods[$m]}; do
                pr_info "  $tns"
            done
            pr_info ""
        done
        pr_info_b "··················································"
    }

    if [ -n "$OVERRIDE_CONFIG" ] ; then
        TNSPEC_ID=${TNSPEC_ID%%.*}
        TNSPEC_ID=${TNSPEC_ID:-${hwid}}.$OVERRIDE_CONFIG
    fi

    local _new_specid=${TNSPEC_ID:-}
    [ -z "$_new_specid" ] && {
        pr_info__ "Compatible HW"
        local spec
        for spec in $_sw_specs; do
            tnspec spec list $spec -g sw -v
        done
        pr_warn "(fused device doesn't support override HW Spec)"

        pr_info ""
        pr_info__ "Current HW"
        local bold=$(tnspec spec list $specid -g sw -v)
        pr_ok "$bold"
        pr_info ""
        local ps=">> "
        [ -n "$method" ] && ps="$method >> "
        _choose_hook=_choose_hook_setup_manual _choose "$ps" "$_sw_specs" _new_specid
    }

    [ -n "$method" ] && ! _in_array $_new_specid ${alt_methods[$method]} && {
        pr_err "'$_new_specid' doesn't support '$method' flashing method" "manual: "
        exit 1
    }

    ! _in_array $_new_specid $_sw_specs && {
        pr_err "HW Spec ID '$_new_specid' is not supported." "tnspec_setup_manual: "
        exit 1
    }

    # Set flash_method
    flash_method=$method

    # save current specid for furture usage
    cur_specid=$specid
    specid=$_new_specid

    # Update config
    local config=${specid##*.}
    nct_update $tnsbin $tnsbin.updated VAL "config=$config"
    nct_diff $tnsbin $tnsbin.updated &&
        pr_info_b "[MANUAL] 'config' didn't change." "tnspec_setup_manual: " ||
        { cp $tnsbin.updated $tnsbin;
        pr_warn "[MANUAL] 'config' changed to $config" "tnspec_setup_manual: "; }
}

# Choose hook for tnspec_setup_manual
_choose_hook_setup_manual() {
    input_hooked=""
    if [ "$1" == "method" ]; then
        [ -z "$2" ] && {
            method=""
            query_hooked=">> "
            return 0
        }
        _in_array "$2" $methods && {
            method="$2"
            query_hooked="$method >> "
        } || {
            pr_err "Unsupported method." "manual: "
        }
    elif [ "$1" == "" ]; then
        pr_err "You need to enter something."
    else
        return 1
    fi
    return 0
}

#
# tnspec_detect_hw nct
# Automatically detect HW type and generate NCT if necessary
#
# [env]
# specid
# - sets TNSPEC ID to 'specid'
#
tnspec_detect_hw() {
    local tnsbin="$1"
    [ -z "$tnsbin" ] && { pr_err "'tnsbin' not specificed." "tnspec_detect_hw: "; exit 1; }

    pr_info "Detecting Hardware...." "tnspec_detect_hw: "

    if [ "$_dryrun" == "1" ]; then
        [ ! -f "$tnsbin" ] && {
            pr_err "[DRYRUN] '$tnsbin' doesn't exist." "tnspec_detect_hw: "
            pr_info_b "[DRYRUN] First run 'recovery' or 'factory' commands in dry-run mode." "tnspec_detect_hw: "
            exit 1
        }
        pr_info "[DRYRUN] Detecting HW using $tnsbin" "tnspec_detect_hw: "
    else
        nct_read $tnsbin > $TNSPEC_OUTPUT || {
                       pr_info   ""
            _cl="1;4;" pr_err    "SOMETHING WENT WRONG."
                       pr_info   ""
            _cl="4;"   pr_info__ "Run it again with verbose mode (flash -v) for logs"
                       pr_info   ""

            pr_err "Couldn't find TNSPEC ID. Try recovery mode." "tnspec_detect_hw: ">&2
            exit 1
        }
    fi

    # Dump NCT partion
    pr_info "NCT Found. Checking TNSPEC."  "tnspec_detect_hw: "

    local hwid=$(tnspec nct dump spec -n $tnsbin 2> $TNSPEC_OUTPUT | _tnspec spec get id -g hw)
    if [ -z "$hwid" ]; then
        pr_err "NCT's spec partition or 'id' is missing in NCT." "tnspec_detect_hw: "
        pr_warn "Dumping NCT..." "tnspec_detect_hw: "
        tnspec nct dump -n $tnsbin >&2
        exit 1
    else
        pr_info "TNSPEC found. Retrieving TNSPEC ID" "tnspec_detect_hw: "
        local config=$(tnspec nct dump spec -n $tnsbin 2> $TNSPEC_OUTPUT | _tnspec spec get config -g hw)
        config=${config:-default}
        local _tns_id=$hwid.$config

        pr_ok_b "TNSPEC ID: $_tns_id" "tnspec_detect_hw: "
        nct_upgrade_tnspec $tnsbin > $TNSPEC_OUTPUT || return 1
        specid=$_tns_id
    fi
}

tnspec_get_sw_variables() {
    [ -z "$var_types" ] || type_init "$(tnspec_get_sw $specid.vars)"
    local sw_vars="signed_vars cfg bct dtb sku odm cfg_override bpmp dtb_bpmp sec_os eks skip_sanitize bl_disable_lock fusebypass"
    sw_vars+=" rcm_bct ebt rcm"
    sw_vars+=" odm_override oem-signed"

    [ "$flash_interface" == "legacy" ] && sw_vars+=" cmd cmd_gvs sufix"

    if [ "$flash_driver" == "tegraflash" ]; then
        sw_vars+=" cfg_override"
        [ "$(getprop version)" == "2" ] && {
            # Dynamically append all keys
            local k
            for k in $(tnspec_get_sw $specid.bct_configs.); do
                sw_vars+=" bct_configs.$k"
            done
            # MTS, SPE
            sw_vars+=" preboot bootpack mce proper spe"
        }
    elif [ "$flash_driver" == "nvflash" ]; then
        sw_vars+=" minbatt no_disp skip_nct preboot bootpack"
    fi

    local _v v
    for v in $sw_vars; do
        readarray -t _v <<< "$(tnspec_get_sw $specid.$v)" || {
            pr_err "Couldn't query $specid.$v" "tnspec_get_sw_variables: "
            exit 1
        }
        [ -z "$var_types" ] || _v=$(getcond $v _v)

        # Convert dots or hyphens to underscores in case we need to read nested key values.
        # e.g. aa.bb.cc => aa_bb_cc
        v=$(varize $v)
        eval "sw_var_$v=\"$_v\""
    done
}

_reboot() {
    local reboot_bin=tegradevflash boot_type=${1:-coldboot}
    if [ "$flash_driver" == "tegraflash" ]; then
        [ "$(getprop chip)" == "0x19" ] && reboot_bin=tegrarcm
        $(nvbin $(getprop $reboot_bin)) $instance --reboot $boot_type > $TNSPEC_OUTPUT
    else
        # Assume nvflash
        _nvflash --force_reset reset 100 > $TNSPEC_OUTPUT
        resume_mode=0
    fi
}

###############################################################################
# NCT Processors
###############################################################################

#
# nct_update <source nct> <updated nct> <format> <values ..>
# - takes override values in various formats (vals, json, variable names)
#
# [args]
# source nct, updated nct
# - Input and output nct files
# type value
# - It can be of the following types:
#   VAR  - takes value as a variable name and evaluates that variable to update
#          NCT. (_JSON will be also evaluated for JSON type)
#          e.g.
#            my_variable="sn=hello;modulex.uuid=nnnn-nnn-nnn"
#            nct_update n1 n2 VAR my_variable
#   VAL  - takes the simple update notation. e.g. sn=123456
#   JSON - takes the JSON format. e.g. '{"sn" : "123456"}'
#
# [returns]
# 0 - Success
#
# May be terminated early if values passed are in a bad format.
#
nct_update() {
    [[ $# < 3 ]] && {
        pr_err "requires at least 3 arguments." "nct_update: "
        return 1
    }
    local src=$1
    local target=$2
    local format=$3
    local v
    shift 3
    [ ! -f "$src" ] && {
        pr_err "$src doesn't exist" "nct_update: "
        return 1
    }
    local tmp=$src.tmp

    _su rm $tmp $target 2> /dev/null
    cp $src $tmp
    cp $src $target
    for v; do
        local hw=""
        local hw_json=""
        if [ "$format" == "VAR" ]; then
            hw=$(eval echo "\$${v}")
            hw_json=$(eval echo "\$${v}_JSON")
        elif [ "$format" == "VAL" ]; then
            hw="$v"
        elif [ "$format" == "JSON" ]; then
            hw_json="$v"
        fi
        [ -n "$hw" ] && pr_ok_bl "Updating TNSPEC [SIMPLE]: '$hw'" "tnspec_update: "
        [ -n "$hw_json" ] && pr_ok_bl "Updating TNSPEC [JSON]: '$hw_json'" "tnspec_update: "
        [ -n "$hw" ] || [ -n "$hw_json" ] &&
            TNSPEC_SET_HW="$hw" TNSPEC_SET_HW_JSON="$hw_json" \
                _tnspec nct update -o $target -n $tmp <<< ""
        cp $target $tmp
    done
    [ -f "$tmp" ] && rm $tmp

}

#
# nct_update_hw_override <source nct> <target nct> <tnspec id>
# - Update NCT using TNSPEC ID.hw_override
#
# Update TNSPEC field in NCT if hw_override key is found in SW spec mapped by
# TNSPEC ID. "hw_override" is an array type, a user can specify a sequence of
# override operations to take place.
#
# hw_override_json takes override keys in JSON format.
#
# [args]
# nct1, nct2
# - nct files
# tnspec id
# - Used to map to a sw spec that defines hw_override/_json
#
# [returns]
# 0 - Success
# 1 - otherwise
#
nct_update_hw_override() {
    [[ $# < 3 ]] && {
        echo $*
        pr_err "requires at least 3 arguments." "nct_update_hw_override: "
        return 1
    }
    local _tnspecid=$3
    local _ifs=$IFS
    IFS=$'\n'
    local _hw_override
    tnspec_preload $_tnspecid
    _hw_override=($(tnspec_get_sw $_tnspecid.hw_override)) || exit 1

    local i
    for ((i=0; i<${#_hw_override[@]};i++)); do
        pr_ok "[$i] Found 'hw_override' : '${_hw_override[$i]}'" \
            "nct_update_hw_override: " > $TNSPEC_OUTPUT
        _hw_override[$i]="'${_hw_override[$i]}'"
    done
    local _hw_override_json=($(tnspec_get_sw $specid.hw_override_json))
    for ((i=0; i<${#_hw_override_json[@]};i++)); do
        pr_ok "[$i] Found 'hw_override_json' : '${_hw_override_json[$i]}'" \
            "nct_update_hw_override: " > $TNSPEC_OUTPUT
        _hw_override_json[$i]="'${_hw_override_json[$i]}'"
    done
    IFS=$_ifs
    eval nct_update $1 $2 VAL ${_hw_override[@]}
    _su rm $2.tmp 2> /dev/null
    cp $2 $2.tmp
    eval nct_update $2.tmp $2 JSON ${_hw_override_json[@]}
}

#
# nct_diff nct1 nct2 [format]
# - Print differences between two NCTs
#
# [args]
# nct1, nct2
# - nct files
# format
# - target entry to compare. "tnspec" is the default.
#
# [returns]
# 0 - When the target entry of both ncts are identical
# 1 - Otherwise
#
nct_diff() {
    local n1="$1"
    local n2="$2"
    local format=${3:-tnspec}

    [ -f "$n1" ] && [ -f "$n2" ] || {
        pr_err "File(s) not found. ('$n1' or '$n2')" "nct_diff: "
        exit 1
    }
    diff -b $n1 $n2 > /dev/null
    if [ $? != 0 ]; then
        _tnspec nct dump $format -n $n1 > $n1.dump$format
        _tnspec nct dump $format -n $n2 > $n2.dump$format
        diff -u $n1.dump$format $n2.dump$format
        rm $n1.dump$format $n2.dump$format
        return 1
    fi
    return 0
}

#
# nct_upgrade_tnspec nct
# - upgrades the old format NCT to a newer version that has the full tnspec.
#
# Old tnspec tool does not export the entire tnspec in NCT, which is critical
# data to reconstruct NCT. This function reads a NCT file and checks if the new
# tnspec is found. If found, it returns immediately, otherwise it attempts to
# find the original HW spec using TNSPEC ID found from the source nct (stored
# in "spec" field), and rebuilds a new NCT. After this, the newly creatly NCT
# is updated with SN from the source NCT.
#
# [args]
# nct
# - nct file to upgrade
#
# [prereq]
# tnspec.json must contain the matching HW spec.
#
# [returns]
# 0 - Success
# 1 - Otherwise
#
nct_upgrade_tnspec() {

    local tnsbin=$1
    local spec
    spec="$(_tnspec nct dump tnspec -n $tnsbin 2> $TNSPEC_OUTPUT)" || {
        pr_err "TNSPEC in NCT doesn't seem valid" "TNSPEC Upgrade: " >&2
        return 1
    }
    if [ -z "$spec" ]; then
        pr_warn "Found old TNSPEC Trying to convert to a newer version." "TNSPEC Upgrade: " >&2

        pr_info "Dumping old TNSPEC" "TNSPEC Upgrade: "
        tnspec nct dump -n $tnsbin 2> $TNSPEC_OUTPUT

        spec=$(_tnspec nct dump spec -n $tnsbin 2> $TNSPEC_OUTPUT)

        [ -z "$spec" ] && {
            pr_err "Couldn't convert old format to new format." "TNSPEC Upgrade: " >&2
            return 1
        }

        local tnsid="$(_tnspec spec get id <<< $spec).$(_tnspec spec get config <<< $spec)"
        [ "$tnsid" == "." ] && {
            pr_err "TNSPEC ID not found." "TNSPEC Upgrade: " >&2
            return 1
        }

        # There are really only a couple of  fields we need to import from the
        # old NCT. Instead of sourcing it from tnspec.json, we just hardcode
        # them here.
        local preserve_list="serial:sn wcc:wcc"
        local t _override _override_JSON
        for e in $preserve_list; do
            local nct_key="${e%:*}"
            local tnspec_key="${e#*:}"
            t="$(_tnspec nct dump $nct_key -n $tnsbin 2> $TNSPEC_OUTPUT)"
            [ -n "$t" ] && _override+="${_override:+;}$tnspec_key=$t"
        done

        # 'misc' under 'spec'
        _override_JSON="$(_tnspec nct dump spec -n $tnsbin 2> $TNSPEC_OUTPUT)"

        local hwids=($(tnspec spec list $tnsid -g hw))
        local hwid=${hwids[0]}

        # Check for tie-breakers
        [ ${#hwids[@]} -gt 1 ] && {
            tiebreakers="$(tnspec spec get $tnsid._nct_tie_breakers. -g sw)"
            for e in ${hwids[@]}; do
                _in_array $e $tiebreakers && {
                    tbs="$(tnspec spec get $tnsid._nct_tie_breakers.$e -g sw)"
                    local found=1
                    for tb in $tbs; do
                        _tnspec nct dump -n $tnsbin 2> $TNSPEC_OUTPUT | grep "$tb" > /dev/null || {
                            found=0
                            break
                        }
                    done
                    [ "$found" == "1" ] && {
                        hwid=$e
                        pr_cyan "Found a tie-breaker. Using '$e'" "TNSPEC Upgrade: " >&2
                        break
                    }
                }
            done
        }

        [ -n "$hwid" ] && {
            pr_ok  "FOUND the matching flash target [$hwid]" "TNSPEC Upgrade: "
            pr_info "[$hwid] $(tnspec spec get $hwid.desc -g hw)" "TNSPEC Upgrade: "
            TNSPEC_SET_HW="$_override" TNSPEC_SET_HW_JSON="$_override_JSON" \
                tnspec nct new $hwid -o $tnsbin.tmp &&
                _su cp $tnsbin.tmp $tnsbin || {
                    pr_err "Convert failed." "TNSPEC Upgrade: " >&2
                    return 1; }
        } || {
            pr_err "Couldn't find the flash target for '$tnsid'" "TNSPEC Upgrade: " >&2
            return 1
        }
        pr_ok_b "Successfully converted to new TNSPEC format." "TNSPEC Upgrade: " >&2
        _tnspec nct dump -n $tnsbin
    fi
}

#
# nct_read nct
# - Reads NCT from device.
#
# [args]
# nct
# - Saves to 'nct'

# [returns]
# 0 - NCT dowloaded successfully
# 1 - Otherwise
nct_read() {
    local tnsbin=$1
    part_read NCT $tnsbin && __tnspec nct dump -n $tnsbin > $TNSPEC_OUTPUT || {
        pr_err "Failed to read NCT" "nct_read: " >&2
        return 1
    }
}

#
# nct_write nct
# - writes nct to device
#
# [args]
# nct
# - NCT to write to device
#
# [returns]
# 0 - Wrote NCT to device successfully
# 1 - Otherwise
#
nct_write() {
    part_write NCT $1
}

###############################################################################
# TNSPEC Command Wrappers
###############################################################################

# tnspec w/o spec
_tnspec() {
    $tnspec_bin "$@" || {
        pr_err "tnspec tool ran into an error." "_tnspec: " >&2
        exit 1
    }
}

# tnspec - expecting error handlers
__tnspec() {
    $tnspec_bin "$@"
}

# tnspec wrapper
tnspec() {
    _tnspec "$@" -s $tnspec_spec
}

# Preload TNSPEC SW
tnspec_preload() {
    local query="$1"
    local _hwid="${query%%.*}"

    [ "$_cached_hwid" != "$_hwid" ] && {
        _cached_tnspec_data="$(TNSPEC_SET_SW="$OVERRIDE_SW" \
                               TNSPEC_SET_SW_JSON="$OVERRIDE_SW_JSON" tnspec spec get "$_hwid" -g sw)"
        _cached_hwid=$_hwid
    }
}

# tnspec spec get wrapper (SW)
tnspec_get_sw() {
    local query="$1"
    ! [[ "$query" =~ . ]] && {
        pr_err "$query doesn't look to be a valid TNSPEC ID" "tnspec_get_sw: "
        exit 1
    }
    local _hwid="${query%%.*}"
    [ "$_cached_hwid" == "$_hwid" ] && {
        local _tnsquery="${query#*.}"
        # if _tnsquery is empty, make sure we replace it with a dot.
        [ -z "$_tnsquery" ] && _tnsquery=.
        _tnspec spec get $_tnsquery <<< $_cached_tnspec_data
    } || {
        TNSPEC_SET_SW="$OVERRIDE_SW" \
        TNSPEC_SET_SW_JSON="$OVERRIDE_SW_JSON" tnspec spec get "$query" -g sw
    }
}

get_var_idx() {
python - <<EOF
import sys
import json
target='''$1'''
mode='''$2'''
vars='''$init_vars'''
var_types='''$init_var_types'''

try:
    vars_dict = json.loads(vars)
    var_types_dict = json.loads(var_types)
except Exception as e:
    print >> sys.stderr, "JSON format error:", repr(e)
    sys.exit(1)
else:
    for k,v in vars_dict.items():
        if target in v:
            var_type = k
            break

    index=None
    for id,lda in var_types_dict[var_type].items():
        if lda == 'default':
            index = id
            continue
        if not lda.startswith('lambda'):
            print >> sys.stderr, "lambda expression expected:", lda
            sys.exit(1)
        fn = eval(lda)
        if fn(mode):
            index = id
            break

    if index is None:
        sys.exit(1)
    print "%s" % index
EOF
}

get_init_var() {
    if [ ! -n "$init_vars" ]; then
        init_vars=$(_tnspec spec get settings.flash.vars -s $PRODUCT_OUT/tnspec.json)
        init_var_types=$(_tnspec spec get var_types -s $PRODUCT_OUT/tnspec.json)
    fi

    local val idx
    local target=$1
    local mode=$2
    idx=$(get_var_idx $target $mode)
    val=($(_tnspec spec get settings.flash.$target -s $PRODUCT_OUT/tnspec.json))
    echo ${val[$idx]}
}

tnspec_select_spec() {
    local spec
    # cmdline provide tnspec spec
    if [ -n "$_tnspec_json_file" ]; then
        spec=$_tnspec_json_file
    else
        local tnspecs=($(_tnspec spec get settings.flash.tnspecs -s $PRODUCT_OUT/tnspec.json))
        if [ -n "$tnspecs" ]; then
            spec=$(get_init_var tnspecs $ecid)
        else
            spec=tnspec.json
        fi
    fi

    if [ ! -f "$PRODUCT_OUT/$spec" ]; then
        if [ -f "$PRODUCT_OUT/${spec/#tnspec/tnspec-public}" ]; then
            spec=${spec/#tnspec/tnspec-public}
        else
            default_spec=tnspec.json
            if [ "$spec" != "$default_spec" ] && [ -f "$PRODUCT_OUT/$default_spec" ]; then
                spec=$default_spec
            elif [ "$spec" != "$default_spec" ] && [ -f "$PRODUCT_OUT/${default_spec/#tnspec/tnspec-public}" ]; then
                spec=${default_spec/#tnspec/tnspec-public}
            else
                pr_err "Error: $spec doesn't exist." "tnspec_selec_spect: " >&2
                return
            fi
        fi
    fi

    tnspec_spec=$PRODUCT_OUT/$spec
    pr_info "Using $tnspec_spec" "tnspec_select_spec: "
}

###############################################################################
# TNSPEC Platform Handler MAIN
###############################################################################
flash_main() {
    # Check for use of restricted internal env variables (TNSPEC_SET_*)
    tnspec_check_env

    tnspec_read_cid

    tnspec_select_spec

    # Check if this file has special variable types
    var_types=$(tnspec spec get var_types)

    # Get flash_driver
    settings=$(tnspec spec get settings.flash) || exit 1

    # Flash driver initialization
    driver_init

    # Check device operating mode
    tnspec_check_mode

    if [ -z "$settings" ]; then
        pr_err "settings not found in $tnspec_spec." "tnspec_init: "
        pr_err "fall back to legacy mode" "tnspec_init: "
        flash_main_legacy
        exit
    fi
    tnspec_server=${TNSPEC_SERVER:-$(tnspec spec get settings.tnspec_server)}

    if [ "$flash_interface" == "legacy" ]; then
        flash_main_legacy
        exit
    fi

    # Make sure we have all the tools
    check_tools_nvidia

    # Check for deprecated options
    tnspec_check_options

    # Initialization
    tnspec_init

    # Get command
    tnspec_command

    case $command in
        auto)
            tnspec_cmd_auto auto "${command_args[@]}"
            ;;
        manual)
            tnspec_cmd_auto manual "${command_args[@]}"
            ;;
        factory)
            tnspec_cmd_factory_reset "${command_args[@]}"
            ;;
        recovery)
            tnspec_cmd_factory_recovery "${command_args[@]}"
            ;;
        tnspec)
            tnspec_cmd_tnspec "${command_args[@]}"
            ;;
        register)
            tnspec_cmd_register update "${command_args[@]}"
            _reboot
            ;;
        test)
            odm_override "${command_args[@]}"
            echo $odmdata
            ;;
    esac

    if [ "$_no_track" != "1" ] && [ -x "$HOST_BIN/track.sh" ]; then
        if _in_array "$command" recovery auto manual factory ; then
            (PRODUCT_OUT="$PRODUCT_OUT" $HOST_BIN/track.sh "$(db_tnspec_get)" &)
        fi
    fi

    exit 0
}

type_init() {
    local types_def=$1
    [ -z "$types_def" ] || _type_init
}

_type_init() {
    # Get list of types
    local type_list="$(_getcond .)"
    local var_list type_name var
    for type_name in $type_list; do
        var_list="$(_getcond $type_name)"
        for var in $var_list; do
            # Convert dots and hyphens to underscores
            var=$(varize $var)
            eval "_type_$var=\$type_name"
        done
    done
}

# Convert $1 to an acceptable var name
varize() {
    local _t=$1
    _t=${_t//./_}
    _t=${_t//-/_}
    echo $_t
}

driver_init() {
    # Initialize settings variable type, if we have
    [ -z "$var_types" ] || type_init "$(_getpropraw vars)"

    flash_driver=$(_getpropraw driver)
    flash_interface=$(_getpropraw interface)

    # Common
    setprop default_board

    # Tegraflash initialization
    if [ "$flash_driver" == "tegraflash" ]; then
        plist="default_cmd version bl bl_mb2 applet chip tegrarcm tegradevflash arg_secure flash_cmd mode_string"
        plist+=" mb2_applet soft_fuses"
        for p in $plist; do
            setprop $p
        done

        # TODO: REMOVE THIS
        # Default properties for Tegraflash
        [ -z "$_prop_bl" ]       && _prop_bl=(cboot.bin cboot.bin.signed)
        [ -z "$_prop_applet" ]   && _prop_applet=(nvtboot_recovery.bin rcm_1_signed.rcm)
        [ -z "$_prop_chip" ]     && _prop_chip=(0x21)
        [ -z "$_prop_tegrarcm" ] && _prop_tegrarcm=tegrarcm
        [ -z "$_prop_tegradevflash" ] && _prop_tegradevflash=tegradevflash
        [ -z "$_prop_arg_secure" ] && _prop_arg_secure=("" "--securedev")
        [ -z "$_prop_flash_cmd" ] && _prop_flash_cmd=("flash;" "secureflash;")
    else
        # NVFLASH (don't bother getting data from tnspec.json)
        _prop_bl=(bootloader.bin bootloader_signed.bin)
        _prop_arg_blob=("" "--blob blob.bin")
    fi

    # Unusual override for property keys
    # TODO: We should revisit this to make this more generic if needed.

    [ -n "$OVERRIDE_PROP_BL" ] && {
        pr_warn_b "Unusual PROPERTY OVERRIDE [BL]" "driver_init: "
        pr_info "[BL] \"${_prop_bl[*]}\" => \"$OVERRIDE_PROP_BL\""  "driver_init: "
        _prop_bl="$OVERRIDE_PROP_BL"
    }
}

# Set correct value of variable (name indicate by $2) according to $1's type
getcond() {
    local type_name=$(varize _type_$1)
    local data_var=$2
    local var_type=${!type_name}

    [ -z "$var_type" ] || {
        var_index=${!var_type}
        [ -n "$var_index" ] && {
            eval "$data_var=(\${$data_var[$var_index]})"
        }
    }
    eval "echo \"\${$data_var[*]}\""
}

_getcond() {
    _tnspec spec get $1 <<< $types_def
}

getprop() {
    local name=_prop_$1
    local data
    if [ -z "$var_types" ]; then
        # Legacy
        # Read fused item if fused.
        [ "$_mode" == "1" ] && {
            eval local count=\${#$name[@]}
            if [ "$count" == "2" ]; then
                eval data=\${$name[1]}
            elif [ "$count" == "1" ]; then
                eval data=\${$name[0]}
            fi
        } || eval data=\${$name[0]}
    else
        data=$(getcond $1 $name)
    fi
    echo $data
}

_getpropraw() {
    _tnspec spec get $1 <<< $settings
}

setprop() {
    eval readarray -t _prop_$1 <<< "$(_getpropraw $1)"
}

tnspec_init() {
    if [ -z "$flash_driver" ]; then
        pr_err "settings.flash.driver is not defined in $tnspec_spec" "tnspec_init: "
        exit 1
    fi

    # Dump ram info
    ram_info_dump

    # Create workspace
    tnspec_init_workspace

    # Initializes OBJ Manager
    obj_init

    # Initializes TNSPEC Server Manager
    server_init

    # Check additional dependencies
    check_deps

    # Check status
    [ "$(flash_status)" == "flashing" ] || [ "$(flash_status)" == "aborted" ] && {
        pr_info ""
        pr_err  "********************  WARNING  ************************"
        pr_info ""
        pr_warn "             FLASHING ABORTED PREVIOUSLY "
        pr_warn "       ('recovery' may be enforced if necessary)"
        pr_info ""
        pr_err  "*******************************************************"
    }

    if [ "$flash_driver" == "tegraflash" ]; then
        tnsbin=${tmpws:+$tmpws/}tnspec.bin
    else
        # Let's play safe about making changes for nvflash
        tnsbin=nct.bin
    fi
    return 0
}

_tnspec_command_menu() {
    pr_warn     "-"
    pr_ok_b     "auto     [method] - flash your device automatically"
    pr_info     "manual   [method] - choose a different or reworked SKU compatible with your device"
    pr_info     "recovery [hw]     - recover your device or change it to different HW"
    pr_info     "tnspec            - view or update TNSPEC stored in device"
    pr_info     "register          - register this device"
    [ "$(getprop arg_secure)" != "--securedev" ] && {
        pr_err  "factory           - factory use only (your device information will be initialized)"
    }
    pr_info ""
}

tnspec_command() {
    # private commands : register, factory
    local supported_cmds="auto manual recovery tnspec register factory test help"

    command=${commands[0]:-$(getprop default_cmd)}
    command_args=(${commands[@]:1})

    # command override
    if [ -n "$board" ] && [ "$command" == "" ]; then
        pr_warn "BOARD ($board) is set. Forcing 'recovery' mode" "command: "
        command=recovery
    elif [ -z "$board" ] && [ "$_unattended" == "1" ]; then
        [ "$command" == "" ] && {
            pr_warn "<command> not set. Non-interactive shell." "command: "
            board=$(getprop default_board)
            [ -n "$board" ] && {
                pr_warn "default_board ($board) found. Forcing 'recovery'" "command: "
                command=recovery
            } || {
                pr_warn "No default_board set. Forcing 'auto'" "command: "
                command=auto
            }
        }
    fi

    # TODO: get TNSPEC storage option from TNSPEC:HW:tnspec_storage
    #       (add this dynamically in db_tnspec_register)
    # Check if target board doesn't store TNSPEC.
    [ -n "$board" ] && {
        local tnsid="$(tnspec spec get $board.id -g hw).$(tnspec spec get $board.config -g hw)"
        tnspec_preload $tnsid
        [ "$(tnspec_get_sw $tnsid.skip_nct)" == "true" ] && {
            # Check if TNSPEC is registered in the server
            pr_warn_b "'$board' does not store TNSPEC in the device. Checking TNSPEC Server.." "command: "
            _in_array "$command" recovery auto manual &&
            [ -z "$(server_only=1 db_tnspec_get)" ] && {
                pr_err "TNSPEC not found in the server. Force 'factory' ('$command' ignored)" "command: "
                command=factory
            }
        }
    }

    while ! _in_array "$command" $supported_cmds; do
        _tnspec_command_menu
        [ "$_unattended" == "1" ] && {
            pr_err_b "Unsupported command [$command]" "command: "
            exit 1
        }
        local _commands
        read -p ">> " _commands
        _commands=($_commands)
        command=${_commands[0]}
        command_args=(${_commands[@]:1})
    done
}

tnspec_check_env() {
    [ -n "$TNSPEC_SET" ]      || [ -n "$TNSPEC_SET_JSON" ] ||
    [ -n "$TNSPEC_SET_HW" ]   || [ -n "$TNSPEC_SET_HW_JSON" ] ||
    [ -n "$TNSPEC_SET_SW" ]   || [ -n "$TNSPEC_SET_SW_JSON" ] ||
    [ -n "$TNSPEC_SET_BASE" ] || [ -n "$TNSPEC_SET_BASE_JSON" ] &&
    {
        unset TNSPEC_SET;      unset TNSPEC_SET_JSON
        unset TNSPEC_SET_HW;   unset TNSPEC_SET_HW_JSON
        unset TNSPEC_SET_SW;   unset TNSPEC_SET_SW_JSON
        unset TNSPEC_SET_BASE; unset TNSPEC_SET_BASE_JSON
        pr_info   ""
        pr_err_b  "******************************************************"
        pr_err_b  "******************************************************"
        pr_err_b  "******************************************************"
        pr_err_b  "******************************************************"
        pr_err_b  "******************************************************"
        pr_info   ""
        pr_warn   "  Use of internal environment variables detected."
        pr_err    "      TNSPEC_SET_* CANNOT BE SET EXTERNALLY."
        pr_info   ""
        pr_err_b  "******************************************************"
        pr_err_b  "******************************************************"
        pr_err_b  "******************************************************"
        pr_err_b  "******************************************************"
        pr_err_b  "******************************************************"
        pr_info   ""
    }
}

tnspec_check_options() {
    # Incompatible options
    [ -n "$_modem" ] ||
    [ -n "$_fused" ] || [ -n "$_battery" ] ||
    [ -n "$_watchdog" ] &&
    {
        unset _fused
        pr_info ""
        pr_err_b  "******************************************************"
        pr_err_b  "******************************************************"
        pr_info   ""
        pr_warn_b "  USE OF UNSUPPORTED OPTIONS DETECTED."
        pr_info   ""
        pr_info_b "  Unsupported options: -z, -e, -m, -f, -b, -w"
        pr_info   ""
        pr_err_b  "******************************************************"
        pr_err_b  "******************************************************"
        pr_info ""
    }
}

check_mode() {
    [ -z "$var_types" ] && { check_mode_legacy; return; }

    ###########################################################################
    ###########################################################################
    ###########################################################################
    # DEPRECATED. DO NOT ADD ANY ADDITIONAL STRINGS. THEY ARE DEFINED IN tnspec.json.
    if [ "$(getprop version)" == "2" ]; then
        case $mode in
            0|1) mode_string="[UNFUSED] Preproduction Mode" ;;
            8)   mode_string="[FUSED] NvProduction Mode" ;;
            a)   mode_string="[FUSED] Secure PKC Mode" ;;
            b)   mode_string="[FUSED] Secure ECC Mode" ;;
            e)   mode_string="[FUSED] Secure PKC with SBK Mode" ;;
            f)   mode_string="[FUSED] Secure ECC with SBK Mode" ;;
            *)   mode_string="[UNKNOWN] PLEASE CHECK YOUR DEVICE." ;;
        esac
    else
        case $mode in
            1) mode_string="[UNFUSED] Preproduction Mode" ;;
            3) mode_string="[UNFUSED] NvProduction Mode" ;;
            5) mode_string="[FUSED] Secure SBK Mode" ;;
            6) mode_string="[FUSED] Secure PKC Mode" ;;
            *) mode_string="[UNKNOWN] PLEASE CHECK YOUR DEVICE." ;;
        esac
    fi
    ###########################################################################
    ###########################################################################
    ###########################################################################

    # Initializes index variables based on rcm_mode
    var_types=$(eval_var_types $rcm_mode)
    local type_list="$(_tnspec spec get . <<< $var_types)"
    for type_name in $type_list; do
        val="$(_tnspec spec get $type_name <<< $var_types)"
        eval "$type_name=$val"
    done

    local _mode_string="$(getprop mode_string)"
    [ -n "$_mode_string" ] && mode_string="$_mode_string"
}

eval_var_types() {
python - <<EOF
import sys
import json
rcm_mode="$1"
var_types='''$var_types'''
try:
    var_dict = json.loads(var_types)
except Exception as e:
    print >> sys.stderr, "JSON format error:", repr(e)
    sys.exit(1)

try:
    var_dict = json.loads(var_types)
    for var in var_dict.keys():
        default_val = None
        found = False
        for val in var_dict[var].keys():
            lda = var_dict[var][val]
            if lda == 'default':
                default_val = val
                continue
            if not lda.startswith('lambda'):
                print >> sys.stderr, "lambda expression expected:", lda
                sys.exit(1)

            # evaluate lambda
            fn = eval(lda)
            if fn(rcm_mode):
                var_dict[var] = val
                found = True
                break

        if not found:
            var_dict[var] = default_val

    print json.dumps(var_dict)

except Exception as e:
   print >> sys.stderr, "Conditional variable format error:", repr(e)
   sys.exit(1)
EOF
}

check_mode_legacy() {
    _mode=0; _signed=0; _secure=0; _err=none
    if [ "$(getprop version)" == "2" ]; then
        case $mode in
            0|1) mode_string="[UNFUSED] Preproduction Mode"
                ;;
            8)   mode_string="[FUSED] NvProduction Mode"
                _mode=2;
                ;;
            a)   mode_string="[FUSED] Secure PKC Mode"
                _mode=1; _signed=1
                ;;
            b)   mode_string="[FUSED] Secure ECC Mode"
                _mode=1; _signed=1
                ;;
            e)   mode_string="[FUSED] Secure PKC with SBK Mode"
                _mode=1; _signed=1; _secure=1
                ;;
            f)   mode_string="[FUSED] Secure ECC with SBK Mode"
                _mode=1; _signed=1; _secure=1
                ;;
            *)   mode_string="[UNKNOWN] PLEASE CHECK YOUR DEVICE."
                _err=unsupported
                ;;
        esac
        [ "$rcm_mode" = "0000000" ] && _mode=unsupported
    else
        case $mode in
            1) mode_string="[UNFUSED] Preproduction Mode"
                ;;
            3) mode_string="[UNFUSED] NvProduction Mode"
                ;;
            5) mode_string="[FUSED] Secure SBK Mode"
                _mode=1; _signed=1; _secure=1
                ;;
            6) mode_string="[FUSED] Secure PKC Mode"
                _mode=1; _signed=1; _secure=1
                ;;
            *) mode_string="[UNKNOWN] PLEASE CHECK YOUR DEVICE."
                _err=unsupported
                ;;
        esac
    fi
}

tnspec_read_cid() {
    if [ "$_dryrun" == "1" ]; then
        ecid=($(_tnspec spec get settings.flash.dryrun_ecid -s $PRODUCT_OUT/tnspec.json))
        if [ -n "$ecid" ]; then
            ecid=$(get_init_var dryrun_ecid $_chip_version)
        else
            # compatible with t210 products
            ecid=12100001deadbeefec1dface12345678
        fi
        ecid=0x${DRYRUN_FUSE:-1}${ecid:1}
    else
        # sets "ecid" and "skip_uid"
        if [ -f $PRODUCT_OUT/tnspec.json ]; then
            tegrarcm_bin=$(_tnspec spec get settings.flash.tegrarcm -s $PRODUCT_OUT/tnspec.json)
            # tegrarcm by default
            [ -z $tegrarcm_bin ] && tegrarcm_bin=tegrarcm

            ecid=$($(nvbin $tegrarcm_bin) $instance --uid | grep BR_CID | cut -d' ' -f2)
        else
            # Assume nvflash
            ecid=$($(nvbin nvflash) $instance --cid | grep BR_CID | cut -d' ' -f2)
        fi
        skip_uid=1
    fi

    ecid=${ecid:2:32}
    [ "${#ecid}" != "32" ] && {
        pr_err "failed to read CID. Is your device in recovery mode?" "tnspec_read_cid: "
        exit 1
    }
}

tnspec_check_mode() {
    rcm_mode=${ecid:0:7}
    local mode=${ecid:0:1}
    local mode_string="UNKNOWN"
    check_mode
    [ "$_err" == "unsupported" ] && {
        pr_err "RCM_VERSION [$rcm_mode] doesn't seem valid. Please check your device." \
               "tnspec_checkmode: "
        [ -z "$_force" ] && {
            pr_warn "(or use -F option to ignore this error)"
            exit 1
        } || _mode=0
    }
    pr_info_b "$mode_string" "FUSED: "
    cid=${ecid:7}
    chipid=$(echo -n "$cid" | sha256sum | cut -f1 -d' ')
    chipid=${chipid:0:32}
    pr_info_b "$cid" "CHIP_ID: "

    [ "$cid" == "0000000000000000000000000" ] && {
        pr_err   "**************************************************"
        pr_err   "**************************************************"
        pr_err_b "     YOUR DEVICE DOES NOT HAVE VALID CHIP ID"
        pr_info  ""
        pr_warn  "     FORCING 'OFFLINE' MODE"
        pr_err   "**************************************************"
        pr_err   "**************************************************"
        _offline=1
    }

    [ "$_verbose" == "1" ] && {
        pr_info_b "$rcm_mode" "RCM: "
        pr_info_b "$rcm_mode$cid" "ECID: "
        pr_info_b "$chipid [Hashed]" "CHIP_ID: "
        local converted=$(_format_chip_id "$ecid" '000000')
        pr_info_b "$converted [Reversed]" "CHIP_ID: "
    }
}

tnspec_init_workspace() {
    local p=${TNSPEC_WORKSPACE:-$HOME/.tnspec}
    # Show error only if directory exists
    [ -d "$p" ] && [ ! -O "$p" ] && {
        pr_err "Terminating as $p is not owned by $USER" "tnspec_init_workspace: "
        [ "$USER" == "root" ] && {
            pr_warn "If you're using 'sudo', this is unnecessary as it will be used internally if needed." "tnspec_init_workspace: "
        }
        exit 1
    }
    workspace=$p/$cid
    [[ $workspace =~ ' ' ]] && {
        pr_err "TNSPEC Workspace cannot contain spaces. (Current workspace: '$p')" "tnspec_init_workspace: "
        pr_err "You can use TNSPEC_WORKSPACE to override the current workspace." "tnspec_init_workspace: "
        exit 1
    }
    [ ! -d "$workspace" ] && {
        mkdir -p $workspace || {
            pr_err "Failed to create workspace directory $workspace" "tnspec_init_workspace: "
            exit 1
        }
    }
    [ -z "$(flash_status)" ] && flash_status "initialized"

    # Create temporary workspace
    tmpws=$workspace/_tmp
    [ -e "$tmpws" ] && _su rm -f $tmpws 2> /dev/null
    mkdir -p $tmpws || {
        pr_err "Failed to create temporary workspace $tmpws" "tnspec_init_workspace: "
        exit 1
    }

    pr_info "$workspace" "TNSPEC_WORKSPACE: "
}

tnspec_cmd_factory() {
    local flash_post=()

    # Add data for factory mode only
    if [ "$origin" == "factory" ]; then
        update_tnspec="${update_tnspec:+$update_tnspec;}factory.date=$(date '+%F %T %Z')"
    fi

    [ "$_verbose" == "1" ] && pr_info_b "$update_tnspec" "$MODE: "

    # Select flash target when 'origin' is 'factory' or 'recovery_hw'
    # Skip when it's 'recovery'
    if [ "$origin" != "recovery" ]; then
        if [ -z "$board" ]; then
            local family=$(tnspec spec get family)
            local boards=$(tnspec spec list all -g hw)
            _cl="1;4;" pr_ok_bl "Supported HW List for $family" "$MODE: "
            tnspec spec list -v -g hw

            [ "$origin" == "recovery_hw" ] && [ -n "$tnspec_source" ] && {
                local _tnsid="$(_tnspec spec get id < $tnspec_source).$(_tnspec spec get config < $tnspec_source)"
                [ "$_tnsid" != "." ] && {
                    pr_info ""
                    _cl="1;4;" pr_cyan "COMPATIBLE TARGETS FOR THIS DEVICE [$_tnsid]"
                    pr_warn "NOTE:"
                    pr_warn "Choose one of the following only if you need to refresh HW spec for the current device."
                    pr_warn "e.g. HW spec has been changed since last flashed."
                    pr_warn "--"
                    tnspec spec list $_tnsid -v -g hw
                    pr_info ""
                }
            }
            _choose_hook=_choose_hook_flash_core _choose "$MODE MODE >> " "$boards" board
        else
            # check if board overrides "config"
            [[ $board =~ : ]] && {
                tnspecid_config_override="${board#*:}"
                board="${board%%:*}"
            }
        fi
    fi

    # Print the new "config"
    [ -n "$tnspecid_config_override" ] && {
       pr_info_b "Overriding 'config' of '$board' => '$tnspecid_config_override'" "config_override: "
    }

    # Set up nct. When origin is 'recovery', NCT will be initialized using the
    # pre-loaded tnspec ($tnspec_source)
    [ "$origin" != "recovery" ] &&
        tnspec_setup $tnsbin board $board ||
        tnspec_setup $tnsbin tnspec $tnspec_source

    # EEPROM Handling
    factory_init_eeprom

    factory_set_sn
    factory_set_macs
    factory_set_partitions

    # skip update NCT for secure-fused device except factory mode
    if [ "$origin" != "recovery" ] || [ "$(getprop arg_secure)" != "--securedev" ]; then
        # Update
        nct_update $tnsbin $tnsbin.updated VAL "$update_tnspec"
        nct_diff $tnsbin $tnsbin.updated || cp $tnsbin.updated $tnsbin

        # register tnspec before flashing
        _tnspec nct dump tnspec -n $tnsbin > $tnsbin.tnspec && {
            db_tnspec_register $tnsbin.tnspec
            db_tnspec_generate_nct $tnsbin || exit 1
        } || {
            pr_err "Error while generating TNSPEC." "$MODE: "
            exit 1
        }
    fi

    # Print the final NCT
    _tnspec nct dump -n $tnsbin

    run_flash || {
        pr_err_b "[ERROR] Flashing failed." "run_flash factory/recovery: "
        exit 1
    }
}

# Check if the target HW has EEPROM
factory_init_eeprom() {
    # Load the current TNSPEC
    local eeproms=${_BOARD_EEPROM:-$(_tnspec nct dump tnspec -n $tnsbin | _tnspec spec get eeproms)}
    [ -z "$eeproms" ] && return 0
    local sources=$(_tnspec spec get sources <<< $eeproms)
    [ -z "$sources" ] && return 0

    # Read EEPROM if needed
    local s _eeprom _eeprom_key _eeprom_instance _eeprom_type _eeprom_data
    _eeprom_data=()
    for s in $sources; do
        _eeprom="$(_tnspec spec get $s <<< $eeproms)"
        [ -z "$_eeprom" ] && {
            pr_err "EEPROM '$_eeprom' is not defined." "factory_init_eeprom: " >&2
            exit 1
        }

        # Check for errors
        _eeprom_instance=$(_tnspec spec get instance <<< $_eeprom)
        _eeprom_type=$(_tnspec spec get type <<< $_eeprom)
        [ -n "$_eeprom_instance" ] && [ -n "$_eeprom_type" ] || {
            pr_err "EEPROM['$_eeprom'] must define 'instance' and 'type'." "factory_init_eeprom: " >&2
            exit 1
        }

        _eeprom_key=$(_tnspec spec get bin <<< $_eeprom)
        [ -z "$_eeprom_key" ] || ! tag=eeprom.$s obj_get $_eeprom_key > /dev/null && {
            # No EEPROM binary has been read. Read and save it once.
            pr_info "Reading EEPROM [$s]" "factory_init_eeprom: "

            local eeprombin=${tmpws:+$tmpws/}eeprom.$s
            eeprom_read $_eeprom_instance $eeprombin && {
                _eeprom_key=$(_obj_key $eeprombin)
                tag=eeprom.$s obj_save $eeprombin
                pr_ok "EEPROM[$s] saved. [$_eeprom_key]" "factory_init_eeprom: "

                # Add obj_key
                _eeprom=$(TNSPEC_SET_BASE=bin=$_eeprom_key _tnspec spec get <<< $_eeprom)
            }
        }
        _reload_eeprom_data
        # Override eeproms
        _eeprom_data+=('{"eeproms":{"!'"$s"'":'"$_eeprom"'}}')
    done
    nct_update $tnsbin $tnsbin.updated JSON "${_eeprom_data[@]}"
    nct_diff $tnsbin $tnsbin.updated || cp $tnsbin.updated $tnsbin

    # Special handling of board information
    local board_info=$(_tnspec nct dump tnspec -n $tnsbin | _tnspec spec get eeproms.boardinfo.data)
    [ -n "$board_info" ] && {
        pr_info "Board information found." "factory_init_eeprom: "
        pr_info "Automatically load device information." "factory_init_eeprom: "
        BOARD_SN=$(_tnspec spec get sn <<< $board_info)
        BOARD_WIFI=$(_tnspec spec get wifi <<< $board_info)
        BOARD_BT=$(_tnspec spec get bt <<< $board_info)
        BOARD_ETH=$(_tnspec spec get eth <<< $board_info)
    }
}


_reload_eeprom_data() {
    local eeprom_file eeprom_spec e

    [ -z "$_eeprom_key" ] && return 1
    eeprom_file="$(obj_get $_eeprom_key)" || help_missing_obj
    eeprom_spec=$(tnspec spec get eeprom_types.$_eeprom_type)
    [ -z "$eeprom_spec" ] && {
        pr_err "Failed to read EEPROM Spec for '$_eeprom_type'" "_reload_eeprom_data: "
        exit 1
    }
    _eeprom=$(TNSPEC_SET_BASE=data=- _tnspec spec get <<< $_eeprom)
    for e in $(_tnspec spec get . <<< $eeprom_spec); do
        local offset fmt repr val
        offset=$(_tnspec spec get $e.offset <<< $eeprom_spec)
        fmt=$(_tnspec spec get $e.fmt <<< $eeprom_spec)
        repr=$(_tnspec spec get $e.repr <<< $eeprom_spec)
        val=$(eeprom_bin_parse $eeprom_file $offset $fmt $repr) || {
            pr_err "EEPROM Parse Error. Check if EEPROM Spec is defined correctly." "_reload_eeprom_data: " >&2
            exit 1
        }
        _eeprom=$(TNSPEC_SET_BASE="data.$e=$val" _tnspec spec get <<< $_eeprom)
    done
}

eeprom_bin_parse() {
python - << EOF
import sys
import struct
eeprom_file="$1"
offset=$2
fmt="$3"
rpr="$4"

with open(eeprom_file, 'rb') as f:
    data = f.read()

if rpr == 'int' or rpr == 'str':
    d = struct.unpack_from(fmt,data,offset)[0]
    print d
elif rpr == 'mac':
    d = struct.unpack_from(fmt,data,offset)
    print ':'.join(map(lambda x: "%02X" % x, d)[::-1])

sys.exit(0)
EOF
}

factory_set_sn() {
    # SERIAL NUMBER
    [ "$BOARD_SN" == "" ] && {
        pr_info_b "[SN]" "$MODE: "
        pr_err "BOARD_SN is not set." "$MODE: "

        [ "$_unattended" != "1" ] && {
            read -p "ENTER SERIAL NUMBER >> " BOARD_SN
        }
    }
    [ -n "$BOARD_SN" ] && {
        update_tnspec="${update_tnspec:+$update_tnspec;}sn=$BOARD_SN"
        pr_ok_b "SN: $BOARD_SN" "$MODE: "
    } || pr_err_b "SN: (missing)" "$MODE: "
}

factory_set_macs() {
    local mac_types="wifi bt eth" skip_type="eth"
    local mac menv t show_help=1

    declare -A mac_envs mac_descs
    mac_envs[wifi]=BOARD_WIFI; mac_descs[wifi]="Wifi"
    mac_envs[bt]=BOARD_BT; mac_descs[bt]="Bluetooth"
    mac_envs[eth]=BOARD_ETH; mac_descs[eth]="Ethernet"

    # skip mac type
    [ -n "$board" ] && {
        local tnsid="$(tnspec spec get $board.id -g hw).$(tnspec spec get $board.config -g hw)"
        skip_type="$(tnspec_get_sw $tnsid.skip_mac)"
        pr_info_b "MAC skipped: $skip_type" "$MODE: "
    }

    for t in $mac_types; do
        menv=${mac_envs[$t]}
        eval mac=\"\$$menv\"
        pr_info_b "[MAC - ${mac_descs[$t]}]" "$MODE: "

        [ "$mac" == "00:00:00:00:00:00" ] || [ "$mac" == "FF:FF:FF:FF:FF:FF" ] || [ "$mac" == "00:FF:FF:FF:FF:FF" ] && {
            pr_err "MAC[$t]:$mac is programmed incorrectly. Need reset." "$MODE: "
            mac=
        }

        [ "$mac" == "" ] && {
            pr_err "$menv is not set." "$MODE: "

            [ "$_unattended" != "1" ] && ! _in_array $t $skip_type && {
                pr_info "ENTER MAC ADDRESS For '${mac_descs[$t]}' (Hit Enter to Skip)" "$MODE: "
                if [ "$show_help" == "1" ]; then
                    show_help=0
                    pr_info ""
                    pr_info__ "Supported MAC Address Formats"
                    pr_info "AA:BB:CC:DD:EE:FF" "· "
                    pr_info "AA-BB-CC-DD-EE-FF" "· "
                    pr_info "AABBCCDDEEFF" "· "
                    pr_info ""
                fi
                while :; do
                    read -p "MAC[$t] >> " $menv
                    eval mac=\"\$$menv\"
                    mac=$(_validate_mac "$mac") && break ||
                        pr_err "MAC[$t] '$mac' is not valid." "$MODE: "
                done
            }
        }
        [ -n "$mac" ] && {
            # Re-validate MAC addresses directly set in environment variables.
            mac=$(_validate_mac "$mac") || {
                pr_err "MAC[$t] '$mac' is not valid." "$MODE: "
                exit 1
            }
            update_tnspec="${update_tnspec:+$update_tnspec;}$t=$mac"
            pr_ok_b "MAC[$t]: $mac" "$MODE: "
        } || pr_warn "MAC[$t] skipped" "$MODE: "
    done
}

_validate_mac() {
python - << EOF
import re
import sys
mac="$1"
if not len(mac):
    sys.exit(0)
m = re.match('^([0-9a-fA-F]{2}[:-]{0,1}){5}[0-9a-fA-F]{2}$',mac)
if m:
    m = m.group(0)
    m = m.upper()
    m = m.replace(':','')
    m = m.replace('-','')
    m = ':'.join([ m[i:i+2] for i in range(0,len(m),2) ])
    print(m)
else:
    print(mac)
    sys.exit(1)
sys.exit(0)
EOF
}

factory_set_partitions() {
    local _cwd=$PWD
    local lintout=${tmpws:+$tmpws/}lintout

    cd $ROOT_PATH
    pr_info ""
    pr_info_b "[EKS]" "$MODE: "
    [ "$BOARD_EKS" == "" ] && {
        pr_warn "BOARD_EKS is not set." "$MODE: "
        [ "$_mode" == "0" ] &&
            pr_warn "(you're probably okay without it since your device is not fused)"

        [ "$_unattended" != "1" ] && {
            read -p "ENTER EKS FILE PATH (hit ENTER to ignore) >> " BOARD_EKS
            # use eval to expand env variables.
            [ -n "$BOARD_EKS" ] && eval BOARD_EKS=$BOARD_EKS
        }
        [ "$BOARD_EKS" == "" ] && pr_warn "BOARD_EKS ignored." "$MODE: "
    }
    if [ "$BOARD_EKS" != "" ]; then
        [ ! -f "$BOARD_EKS" ] && {
            pr_err_b "[EKS] Not found : $BOARD_EKS" "$MODE: "
            exit 1
        }
        local _eks_org=$BOARD_EKS
        tnspec_lint eks $BOARD_EKS $lintout.eks > $TNSPEC_OUTPUT &&
            BOARD_EKS=$lintout.eks || {
                pr_err_b "[EKS] Invalid EKS : $BOARD_EKS" "$MODE: "
                exit 1
            }
        tag=eks obj_save $BOARD_EKS
        pr_ok_b "EKS: $BOARD_EKS (linted from $_eks_org)" "$MODE: "
    fi
    pr_info ""

    pr_info_b "[FCT]" "$MODE: "
    [ "$BOARD_FCT" == "" ] && {
        pr_warn "BOARD_FCT is not set." "$MODE: "

        # No manual prompt for FCT (it's almost always skipped)
        false && {
            read -p "ENTER FCT FILE PATH (hit ENTER to ignore) >> " BOARD_FCT
            [ -n "$BOARD_FCT" ] && eval BOARD_FCT=$BOARD_FCT
        }
        [ "$BOARD_FCT" == "" ] && pr_warn "BOARD_FCT ignored." "$MODE: "
    }
    if [ "$BOARD_FCT" != "" ]; then
        [ ! -f "$BOARD_FCT" ] && {
            pr_err_b "[FCT] Not found : $BOARD_FCT" "$MODE: "
            exit 1
        }
        tnspec_lint fct $BOARD_FCT > $TNSPEC_OUTPUT || {
            pr_err_b "[FCT] Invalid FCT : $BOARD_FCT" "$MODE: "
            exit 1
        }

        tag=fct obj_save $BOARD_FCT
        pr_ok_b "FCT: $BOARD_FCT" "$MODE: "
    fi

    if [ "$BOARD_CONST_NCT" != "" ]; then
        [ ! -f "$BOARD_CONST_NCT" ] && {
            pr_err_b "[NCT] Not found : $BOARD_CONST_NCT" "$MODE: "
            exit 1
        }

        # TODO: add NCT validation here
        tag=nct obj_save $BOARD_CONST_NCT
        pr_ok_b "NCT: $BOARD_CONST_NCT" "$MODE: "
    fi

    # Update flash_post
    local s
    if [ "$BOARD_EKS" != "" ]; then
        s=$(_obj_key $BOARD_EKS)
        update_tnspec="${update_tnspec:+$update_tnspec;}partitions.eks=$s"
        # XXX:HACK
        # Change this altogether when generic partition protection is added.
        local eks_partname=EKS
        [ "$flash_driver" == "tegraflash" ] && [ "$(getprop version)" == "2" ] && eks_partname=eks
        flash_post+=("$eks_partname $BOARD_EKS")
    fi
    if [ "$BOARD_FCT" != "" ]; then
        s=$(_obj_key $BOARD_FCT)
        update_tnspec="${update_tnspec:+$update_tnspec;}partitions.fct=$s"
        flash_post+=("FCT $BOARD_FCT")
    fi

    if [ "$BOARD_CONST_NCT" != "" ]; then
        s=$(_obj_key $BOARD_CONST_NCT)
        update_tnspec="${update_tnspec:+$update_tnspec;}partitions.nct=$s"
        flash_post+=("NCT $BOARD_CONST_NCT")
    fi

    cd $_cwd
}

_choose_hook_flash_core() {
    input_hooked=""
    tnspecid_config_override=""
    if [ "$1" == "list" ]; then
        tnspec spec list -v -g hw
    elif [ "$1" == "all" ]; then
        tnspec spec list all -v -g hw
    elif [ "$1" == "env" ]; then
        pr_warn "BOARD_SN='$BOARD_SN'"
        pr_warn "BOARD_EKS='$BOARD_EKS' BOARD_FCT='$BOARD_FCT'"
        pr_warn "BOARD_WIFI='$BOARD_WIFI' BOARD_BT='$BOARD_BT' BOARD_ETH='$BOARD_ETH'"
    elif [ "$1" == "" ]; then
        pr_info "Available Commands:"
        pr_info__ "'all', 'list', 'env'"
    elif [[ $1 =~ : ]]; then
        # if input contains ":", truncate everything after : since string after
        # that is used to override "config"
        input_hooked="${1%%:*}"
        tnspecid_config_override="${1#*:}"
        return 1
    else
        return 1
    fi
    return 0
}

tnspec_cmd_factory_reset() {
    [ "$_unattended" == "1" ] && [ -z "$board" ] && {
        pr_err "BOARD must be set in unattended mode" "recovery: "
        exit 1
    }

    MODE=FACTORY

    pr_err_b "----------------------------------------------"
    pr_err_b "   FACTORY MODE. EVERYTHING WILL BE REMOVED"
    pr_err_b "----------------------------------------------"

    origin=factory tnspec_cmd_factory
}

tnspec_check_registered() {
    tnspec_source=$(server_only=1 db_tnspec_get)
    local register=0
    if [ -z "$tnspec_source" ]; then
        register=1
    else
        if [ "$(getprop arg_secure)" == "--securedev" ]; then
            [ "$(_tnspec spec get partitions.nct < $tnspec_source)" == "" ] ||
            [ "$(_tnspec spec get partitions.eks < $tnspec_source)" == "" ] ||
            [ "$(_tnspec spec get partitions.fct < $tnspec_source)" == "" ] && register=1
        fi
    fi

    if [ $register -eq 1 ]; then
        pr_err "$cid not registered." "RECOVERY: "
        tnspec_cmd_register update
        tnspec_source=$(db_tnspec_get)
        [ -z "$tnspec_source" ] && {
            pr_err "Couldn't find TNSPEC from device. factory reset required." "RECOVERY: "
            exit 1
        }
    fi
}

tnspec_cmd_factory_recovery() {
    tnspec_check_registered

    MODE=RECOVERY
    BOARD_SN=${BOARD_SN:-$(_tnspec spec get sn < $tnspec_source)}
    BOARD_WIFI=${BOARD_WIFI:-$(_tnspec spec get wifi < $tnspec_source)}
    BOARD_BT=${BOARD_BT:-$(_tnspec spec get bt < $tnspec_source)}
    BOARD_ETH=${BOARD_ETH:-$(_tnspec spec get eth < $tnspec_source)}
    BOARD_EKS=${BOARD_EKS:-$(db_tnspec_find_obj eks)} || help_missing_obj EKS
    BOARD_FCT=${BOARD_FCT:-$(db_tnspec_find_obj fct)} || help_missing_obj FCT
    BOARD_CONST_NCT=${BOARD_CONST_NCT:-$(db_tnspec_find_obj nct)} || help_missing_obj NCT
    _BOARD_EEPROM=$(_tnspec spec get eeproms < $tnspec_source)

    origin=recovery

    if [ -z "$board" ]; then
        if [ "$1" == "hw" ]; then
            [ "$_unattended" == "1" ] && {
                pr_err "BOARD must be set for 'recovery hw' in unattended mode" "tnspec_cmd_factory_recovery: "
                exit 1
            }
            local _hw
            pr_info_b "Hit <ENTER> for auto-recovery. Enter 'hw' to choose new board."
            read -p ">> " _hw
            [ "$_hw" == "hw" ] && origin=recovery_hw
        elif [ -n "$1" ]; then
            board="$1"
            origin=recovery_hw
        fi
    else
        # Since $board is already set, origin needs to be updated to
        # "recovery_hw" instead of the default value "manual".
        origin=recovery_hw
    fi
    tnspec_cmd_factory
}

tnspec_cmd_tnspec() {
    if [ "$_unattended" == "1" ] && [ -z "$BOARD_UPDATE" ] && [ -z "$BOARD_UPDATE_JSON" ] ; then
        pr_err_b "BOARD_UPDATE[_JSON] not set for unattended mode." "UPDATE: "
        exit 1
    fi
    local _tnsbin=${tmpws:+$tmpws/}tnsbin.dev
    local _tns=$_tnsbin.tnspec
    pr_info "Reading TNSPEC..." "UPDATE: "

    [ "$_dryrun" == "1" ] && {
        local tmp=$(db_tnspec_get)
        [ -z "$tmp" ] && { pr_err "TNSPEC not found."; return 1; }
        _su rm $_tns 2> /dev/null
        cp $tmp $_tns
        cp $_tns $_tns.updated
        _tnspec nct new -o $_tnsbin <  $_tns.updated
    } || {
        nct_read $_tnsbin && cp $_tnsbin $_tnsbin.org
        nct_upgrade_tnspec $_tnsbin &&
        __tnspec nct dump tnspec -n $_tnsbin.org > $_tns 2> $TNSPEC_OUTPUT &&
        __tnspec nct dump tnspec -n $_tnsbin > $_tns.updated || {
            pr_err "TNSPEC not found. 'recovery' or 'factory' needed" "UPDATE: " >&2
            exit 1
        }
    }

    local p="set | sync_db | revert | view [pending] | diff | save/register [force] | quit"

    if [ -n "$BOARD_UPDATE" ] || [ -n "$BOARD_UPDATE_JSON" ] ; then
        # modify NCT directly
        nct_update $_tnsbin $_tnsbin.updated VAR BOARD_UPDATE
        nct_diff $_tnsbin $_tnsbin.updated &&
            pr_info_b "[BOARD_UPDATE] Nothing to update." "UPDATE: " || {
            _tnspec nct dump tnspec -n $_tnsbin.updated > $_tns.updated
            [ "$1" == "register" ] && {
                _tnspec_cmd_tnspec_register $_tns.updated $_tnsbin.updated
            }
            pr_warn "Updating.." "UPDATE: "
            nct_write $_tnsbin.updated
            pr_ok_b "[BOARD_UPDATE] TNSPEC has been updated." "UPDATE: "
        }
    else
        # interactive mode
        local c _update
        cp $_tns $_tns.tmp
        while true; do
            pr_info_b "$p"
            read -p ">> " c
            eval local _c=("$c")
            local a=${_c[@]:1}
            local C=${_c[0]}
            case $C in
                set)
                    _update="$a"
                    TNSPEC_SET_BASE=$_update _tnspec spec get < $_tns.tmp > $_tns.updated
                    cp $_tns.updated $_tns.tmp
                    diff -u $_tns $_tns.updated
                    ;;
                sync_db)
                    local db="$(server_only=1 db_tnspec_get)"
                    [ -n "$db" ] && {
                        cp $db $_tns.updated
                        cp $_tns.updated $_tns.tmp
                    } || pr_err "Couldn't load TNSPEC from DB" "tnspec: "
                    diff -u $_tns $_tns.updated
                    ;;
                revert)
                    cp $_tns $_tns.tmp
                    cp $_tns $_tns.updated
                    ;;
                view)
                    [ "$a" == "pending" ] &&
                        _tnspec spec get < $_tns.updated ||
                        _tnspec spec get < $_tns
                    ;;
                diff)
                    diff -u $_tns $_tns.updated
                    ;;
                save|register)
                    if [ "$a" != "force" ] && diff -u $_tns $_tns.updated; then
                        pr_info "[tnspec] Nothing to update." "UPDATE: "
                    else
                        _tnspec nct new -o $_tnsbin.updated <  $_tns.updated
                        [ "$C" == "register" ] && {
                            _tnspec_cmd_tnspec_register $_tns.updated $_tnsbin.updated
                        }
                        [ "$_dryrun" == "1" ] && break
                        pr_warn "Updating.." "UPDATE: "
                        nct_write $_tnsbin.updated
                        pr_ok_b "[tnspec] TNSPEC has been updated." "UPDATE: "
                        break
                    fi
                    ;;
                quit)
                    break
                    ;;
            esac
        done
        rm $_tns.tmp
    fi
    [ "$_dryrun" == "1" ]  && return 0
    _reboot
}

_tnspec_cmd_tnspec_register() {
    local tns="$1"
    local tns_nct="$2"
    pr_cyan "[tnspec] registering..." "TNSPEC_SERVER: "
    [ -e "$tns_nct.org" ] && [ ! -w "$tns_nct.org" ] && _su rm $tns_nct.org
    cp $tns_nct $tns_nct.org || exit 1
    origin=tnspec_cmd db_tnspec_register $tns
    # Generate a new NCT using TNSPEC from the server
    db_tnspec_generate_nct $tns_nct || exit 1
    nct_diff $tns_nct.org $tns_nct && pr_info "[tnspec] TNSPEC unchanged." "TNSPEC_SERVER: "
}

tnspec_cmd_auto() {
    local status=$(cat $workspace/status)
    [ "$status" == "aborted" ] || [ "$status" == "flashing" ] && {
        pr_err   "**************************************************"
        pr_err   "**************************************************"
        pr_err_b " FLASHING ABORTED PREVIOUSLY. Forcing 'RECOVERY'"
        pr_err   "**************************************************"
        pr_err   "**************************************************"
        tnspec_cmd_factory_recovery
        return
    }

    # Will be set by tnspec_setup
    local flash_method

    tnspec_setup $tnsbin "$@"

    # check if registered
    tnspec_check_registered

    local flash_post _eks _fct _nct
    # TODO: eks/fct should come from device first?
    _eks=$(db_tnspec_find_obj eks) || help_missing_obj EKS

    # XXX:HACK
    # Change this altogether when generic partition protection is added.
    local eks_partname=EKS
    [ "$flash_driver" == "tegraflash" ] && [ "$(getprop 2)" == "2" ] && eks_partname=eks
    # XXX:HACK

    [ -n "$_eks" ] && flash_post+=("$eks_partname $_eks")
    _fct=$(db_tnspec_find_obj fct) || help_missing_obj FCT
    [ -n "$_fct" ] && flash_post+=("FCT $_fct")

    _nct=$(db_tnspec_find_obj nct) || help_missing_obj NCT
    [ -n "$_nct" ] && flash_post+=("NCT $_nct")

    _tnspec nct dump -n $tnsbin

    # locally register tnspec before flashing
    # NOTE: it it important that we don't register tnspec to server when 'auto' is used.
    #       'register'-class commands must be explicitly used to update to the server.
    _tnspec nct dump tnspec -n $tnsbin > $tnsbin.tnspec &&
        local_only=1 db_tnspec_register $tnsbin.tnspec

    if [ -z "$flash_method" ]; then
        run_flash || {
            pr_err_b "[ERROR] Flashing failed." "run_flash auto/manual: "
            exit 1
        }
    else
        run_flash_alternate $specid $flash_method
    fi
}

tnspec_cmd_register() {
    local update="$1"
    local _tnsbin=${tmpws:+$tmpws/}tnsbin.dev
    local _tns=$_tnsbin.tnspec

    [ "$(getprop arg_secure)" == "--securedev" ] && [ -n "$board" ] && {
        specid="$(tnspec spec get $board.id -g hw).$(tnspec spec get $board.config -g hw)"
        tnspec_preload $specid
        tnspec_get_sw_variables
    }

    pr_info "Reading TNSPEC" "REGISTER: "
    nct_read $_tnsbin && nct_upgrade_tnspec $_tnsbin &&
        __tnspec nct dump tnspec -n $_tnsbin > $_tns || {
            pr_err "TNSPEC not found. Please try 'recovery' or 'factory' command." "REGISTER: " >&2
            exit 1
        }
    local _tns_id="$(_tnspec spec get id < $_tns).$(_tnspec spec get config < $_tns)"
    [ -z "$_tns_id" ] && {
        pr_err "TNSPEC not found. Please try 'recovery' or 'factory' command." "REGISTER: " >&2
        exit 1
    }

    [ "$(getprop arg_secure)" == "--securedev" ] && [ ! -n "$board" ] && {
        [ -z "$specid" ] && specid=$_tns_id
        tnspec_preload $specid
        tnspec_get_sw_variables
    }

    local s

    # secure-fused device keep NCT constant, hence save to server
    if [ "$(getprop arg_secure)" == "--securedev" ]; then
        # TODO: add tnspec NCT valdiate here
        [ -f "$_tnsbin" ] && {
            pr_info_b "[NCT] Validated." "REGISTER: "
            s=$(_obj_key $_tnsbin)
            TNSPEC_SET_BASE="partitions.nct=$s" _tnspec spec get < $_tns > $_tns.updated
            cp $_tns.updated $_tns
            tag=nct obj_save $_tnsbin
        } || {
            pr_err "[NCT] invalid NCT partition. Ignored." "REGISTER: "
            TNSPEC_SET_BASE="partitions.nct=-" _tnspec spec get < $_tns > $_tns.updated
            cp $_tns.updated $_tns
        }
    fi

    local _ptbin=${tmpws:+$tmpws/}eks.device
    pr_info "[EKS] Reading..." "REGISTER: "
    [ -e "$_ptbin" ] && _su rm -f $_ptbin 2> /dev/null
    part_read EKS $_ptbin && tnspec_lint eks $_ptbin $_ptbin.lint > $TNSPEC_OUTPUT && {
        pr_info_b "[EKS] Validated." "REGISTER: "
        s=$(_obj_key $_ptbin.lint)
        TNSPEC_SET_BASE="partitions.eks=$s" _tnspec spec get < $_tns > $_tns.updated
        cp $_tns.updated $_tns
        tag=eks obj_save $_ptbin.lint
    } || {
        # FIXME: terminate if it's production mode
        pr_err "[EKS] invalid EKS partition. Ignored." "REGISTER: "
        TNSPEC_SET_BASE="partitions.eks=-" _tnspec spec get < $_tns > $_tns.updated
        cp $_tns.updated $_tns
    }

    local _ptbin=${tmpws:+$tmpws/}fct.device
    pr_info "[FCT] Reading..." "REGISTER: "
    [ -e "$_ptbin" ] && _su rm -f $_ptbin 2> /dev/null
    part_read FCT $_ptbin && tnspec_lint fct $_ptbin > $TNSPEC_OUTPUT && {
        pr_info_b "[FCT] Validated." "REGISTER: "
        s=$(_obj_key $_ptbin)
        TNSPEC_SET_BASE="partitions.fct=$s" _tnspec spec get < $_tns > $_tns.updated
        cp $_tns.updated $_tns
        tag=fct obj_save $_ptbin
    } || {
        # FIXME: terminate if it's production mode
        pr_err "[FCT] invalid FCT partition. Ignored." "REGISTER: "
        TNSPEC_SET_BASE="partitions.fct=-" _tnspec spec get < $_tns > $_tns.updated
        cp $_tns.updated $_tns
    }

    origin=device db_tnspec_register $_tns

    [ "$update" == "update" ] && {
        db_tnspec_generate_nct $_tnsbin.reg || exit 1
        nct_write $_tnsbin.reg || {
            pr_err "Failed to write TNSPEC to device." "REGISTER: " >&2
            exit 1
        }
    }
}

tnspec_lint() {
    local partition="$1"; shift
    if [ "$partition" == "eks" ]; then
        _tnspec_lint_eks "$@"
    elif [ "$partition" == "fct" ]; then
        _tnspec_lint_fct "$@"
    fi
}

_tnspec_lint_eks() {
python - << EOF
import struct
import zlib
import sys

src = "$1"
dst = "$2"

with open(src,'r') as f:
    data = f.read()
    size = struct.unpack('i',data[:4])[0]
    _data = data[4:]
    if len(_data) < size:
        print("tnspec_lint_eks: File size too small.")
        sys.exit(1)
    if _data[:6] != 'NVEKSP':
        print("tnspec_lint_eks: Magic HDR not found.")
        sys.exit(1)
    _data = data[:size+4]
    if zlib.crc32(_data[4:-4]) != struct.unpack('i',_data[-4:])[0]:
        print("tnspec_lint_eks: CRC32 mismatch")
        sys.exit(1)
if dst:
    with open(dst,'w') as f:
        f.write(_data)

sys.exit(0)
EOF
}

_tnspec_lint_fct() {
python - << EOF
import sys
import struct
with open("$1", 'r') as f:
    x = f.read()
    if len(x) < 1082:
        print("tnspec_lint_fct: can't find superblock for ext4.")
        sys.exit(1)
    if struct.unpack('H',x[1080:1082])[0] != 0xef53:
        print("tnspec_lint_fct: ext4 magic number not found.")
        sys.exit(1)
sys.exit(0)
EOF
}

_format_chip_id() {
python - << EOF
cid="$1"
padding="$2"
cid = [ cid[i:i+2] for i in range(0,len(cid),2) ][::-1]
print(''.join(cid)[:-len(padding)] + padding)
EOF
}

###############################################################################
# TNSPEC Registration/Fetch
###############################################################################
db_tnspec_register() {
    local file="$1"
    local tns_server_json=${tmpws:+$tmpws/}tnspec_server.json

    # Make sure $file is readable. There is really no reason $file is not
    # accessible, but we've seen signature registered with empty strings.
    [ -r "$file" ] || {
        pr_err "'$file' is not readable. Something went wrong." "db_tnspec_register: " >&2
        exit 1
    }

    # Update registration information

    # TODO: get real user information
    local reg_info
    reg_info="registered.origin=${origin:-manual}"
    reg_info="$reg_info;registered.user=$USER@$HOSTNAME"
    reg_info="$reg_info;rcm_mode=$rcm_mode;chipid=$chipid"
    reg_info="$reg_info;meta=-;revision=-;signature=-"
    TNSPEC_SET_BASE="$reg_info" _tnspec spec get < $file > $file.updated
    cp $file.updated $file

    # Add TNSPEC signature
    reg_info="signature=$(_obj_key $file)"
    TNSPEC_SET_BASE="$reg_info" _tnspec spec get < $file > $file.updated
    cp $file.updated $file

    tag=_tnspec _obj_save "$file" tnspec.local

    [ "$local_only" == "1" ] && return 0

    [ "$tns_online" == "1" ] && {
        local params="$tnspec_server/tnspec/$cid?user=$USER@$HOSTNAME&type=dev"
        local res=$(curl -ks -m 10 -X POST -H "Content-Type: application/json" -d@$workspace/tnspec.local "$params")
        server_return "$res" && _db_tnspec_get $tns_server_json && {
            tag=tnspec _obj_save $tns_server_json tnspec
            pr_cyan "registered to server." "tnspec_register: "
        } || {
            pr_err "failed to register to server." "tnspec_register: "
            [ -z "$_force" ] && {
                pr_info "Flash with '-F' option to ignore this error."
                exit 1
            } ||  return 1
        }
    }
}

db_tnspec_get() {
    # always try to get the latest tnspec
    local tns_server_json=${tmpws:+$tmpws/}tnspec_server.json
    if [ "$tns_online" == "1" ];then
        _db_tnspec_get $tns_server_json && {
            # ignore tag to skip logging
            _obj_save $tns_server_json tnspec
            echo "$workspace/tnspec"
            return
        }
    fi

    [ "$tns_online" == "1" ] && [ "$server_only" == "1" ] && return

    # try tnspec.local
    [ -f "$workspace/tnspec.local" ] && {
        echo "$workspace/tnspec.local"
        return
    }

    # otherwise, use cached tnspec if found.
    [ -f "$workspace/tnspec" ] && {
        echo "$workspace/tnspec"
        return
    }

    # unregistered device
}

_db_tnspec_get() {
    local target="$1"
    local params="$tnspec_server/tnspec/$cid?user=$USER@$HOSTNAME"
    curl -ks -m 30 "$params" > $target.tmp &&
        _tnspec spec get < $target.tmp > $target &&
        [ "$(_tnspec spec get chipid < $target)" != "" ] && {
            rm $target.tmp
            return 0
        }
    pr_warn "Could not find TNSPEC from server." "_db_tnspec_get: " >&2
    return 1
}

db_tnspec_find_obj() {
    local t="$1"
    local tns="$(db_tnspec_get)"
    [ -z "$tns" ] && return 1

    local key="$(_tnspec spec get partitions.$t < $tns)"
    [ "$key" == "" ] && return 0
    tag=$t obj_get $key && return 0 || return 1
}

# Generate NCT from the latest tnspec
db_tnspec_generate_nct() {
    local target_nct="$1"
    local tns=$(db_tnspec_get)
    [ -z "$tns" ] && {
        pr_err "TNSPEC is not found" "db_tnspec_generate_nct: " >&2
        return 1
    }
    _tnspec nct new -o $target_nct < $tns || {
        pr_err "Failed to generate NCT" "db_tnspec_generate_nct: " >&2
        return 1
    }
}
###############################################################################
# TNSPEC Server Manager
###############################################################################
server_init() {
    [ "$_offline" == "1" ] && {
        pr_warn "** OFFLINE MODE **" "TNSPEC_SERVER: "
        return
    }
    # Check if tnspec server is online
    local res="$(curl -sk -m 5 $tnspec_server 2> $TNSPEC_OUTPUT)"
    [ "$res" == "tnspec server" ] && {
        tns_online=1
        pr_cyan_b "$tnspec_server [ONLINE]" "TNSPEC_SERVER: "
    } || pr_err_b "$tnspec_server [OFFLINE]" "TNSPEC_SERVER: "
}

server_return() {
    local s="$1"
    local code="${s%%:*}"
    [[ $s =~ : ]] && {
        local msg="${s#*:}"
        [ "$code" == "OK" ] &&
            pr_cyan_b "[OK] $msg" "TNSPEC_SERVER: " ||
            pr_err_b "[ERROR] $msg" "TNSPEC_SERVER: "
    }

    [ "$code" == "OK" ] && return 0 || return 1
}

###############################################################################
# OBJ Manager
###############################################################################

obj_init() {
    [ -f "$workspace/logs" ] && {
        local lineno=$(wc -l < $workspace/logs)
        if [ "$lineno" -gt "1000" ]; then
            mv -f $workspace/logs $workspace/logs.old
        fi
    }
    ws=$workspace/o
    [ ! -d "$ws" ] && mkdir -p $ws
}

# obj_save <file>
obj_save() {
    local file="$1"

    _obj_save "$file"

    [ "$tns_online" != "1" ] && {
        pr_warn "TNSPEC Server is OFFLINE. OBJ[$(_obj_key $file)] not uploaded." "obj_save: "
        return
    }

    local k=$(_obj_key "$file")
    local o_status="$(_obj_status_sync $k)"

    if [ "$o_status" == "notfound" ]; then
        gzip < "$file" > $k.gz
        local params="$tnspec_server/o?o=$k&type=$tag&user=$USER@$HOSTNAME"
        local result=$(curl -ks -X POST -F file=@$k.gz "$params")
        server_return "$result" && pr_info "[$k] saved to server." "obj_save: " ||
                                   pr_err "[$k] wasn't saved to server." "obj_save: "
        rm $k.gz
    fi
}

# _obj_save <file> [symlink]
_obj_save() {
    local file="$1"
    local sym="$2"

    [ ! -f "$file" ] && {
        pr_err "'$file' not found." "_obj_save: "
        exit 1
    }
    local k=$(_obj_key "$file")
    local obj=$ws/$k
    [ ! -f "$obj" ] && cp "$file" "$obj"

    # Create a (relative) symlink when requested.
    [ -n "$sym" ] && ln -sf o/$k $workspace/$sym

    [ -n "$tag" ] && tnspec_logger $tag $k
}

# obj_get <key>
# returns <obj>
obj_get() {
    [ -z "$1" ] && return

    local k="$1"
    local path="$(_obj_get $k)"

    [ -n "$path" ] && {
        echo "$path"
        # Check if tnspec server has this resource. If not, save it.
        [ "$tns_online" == "1" ] && [ "$(_obj_status_sync $k)" == "notfound" ] && {
            pr_info "Found object [$k] locally, but missing in server. Uploading..." "obj_get: " >&2
            obj_save $path >&2
        }
        return 0
    }

    [ "$tns_online" != "1" ] && {
        pr_err "TNSPEC Server is offline. Couldn't find object [$k]." "obj_get: " >&2
        return 1
    }

    local o_status="$(_obj_status_sync $k)"

    if [ "$o_status" == "notfound" ]; then
        pr_err "[$k] not found." "obj_get: " >&2
        return 1
    elif [ "$o_status" == "pending" ]; then
        pr_err "[$k] is being prepared. Try again in a few minutes." "obj_get: " >&2
        return 1
    elif [ "$o_status" == "ready" ]; then
        pr_cyan "[$k] dowloading..." "obj_get: " >&2
        local params="$tnspec_server/o/$k?user=$USER@$HOSTNAME"
        curl -ks -m 60 "$params" > $k.gz &&
            gunzip $k.gz && _obj_save $k &&
            rm $k && pr_cyan "[$k] complete" "obj_get: " >&2 || {
                pr_err "ERROR while getting data" "obj_get: " >&2
                return 1
            }
    else
        pr_err "Unkown Error" "obj_get: " >&2
        pr_info "-----------------" >&2
        pr_warn "$o_status" >&2
        pr_info "-----------------" >&2
        return 1
    fi
    echo "$(_obj_get $k)"
}
_obj_get() {
    [ ! -f "$ws/$1" ] && return 1
    echo "$ws/$1"
}
_obj_key() {
    echo $(sha256sum "$1" | cut -f1 -d' ')
}
_obj_status_sync() {
    [ "$tns_online" != "1" ] && {
        pr_err "server is offline" "_obj_status_sync: " >&2
        echo "server offline"
        return 1
    }
    local o_status=$ws/$1.status
    if [ ! -f "$o_status" ] || [ "$(cat $o_status)" != "ready" ]; then
        curl -ks -m 5 $tnspec_server/o/$k?status > $o_status
    fi
    echo "$(cat $o_status)"
}

# Logger
tnspec_logger() {
    printf "[%s] %-8s %s\n" "$(date)" "$1" "$2" >> $workspace/logs
}

###############################################################################
# OLD FLASH MAIN
###############################################################################
flash_main_legacy() {
    tnsbin=nct.bin

    [ "$_mode" != "0" ] && {
        pr_err "[Flashing FUSED devices]" "fused: "
    }

    check_tools_nvidia

    if [ -n "$settings" ] && [ "$_unattended" == "1" ]; then
        board=${board:-$(getprop default_board)}
    fi

    local boards=$(tnspec spec list all -g hw)
    if [ -z "$board" ] && [ "$_unattended" != "1" ] ; then
        local family=$(tnspec spec get family)
        _cl="1;4;" pr_ok_bl "Supported HW List for $family" "TNSPEC: "
        pr_warn "Choose \"auto\" to automatically detect HW" "TNSPEC: "
        tnspec spec list -v -g hw
        pr_info ""
        pr_info_b "'help' - usage, 'list' - list frequently used, 'all' - list all supported"
        board_default=${board_default:-auto}
        _cl="1;" pr_ok "[Press Enter to choose \"$board_default\"]"
        _choose_hook=_choose_hook_flash_main_legacy \
            _choose "DEFAULT:\"$board_default\" >> " "auto $boards" board
    else
        board=${board:-auto}
    fi

    [ "$board" == "auto" ] &&
        tnspec_setup $tnsbin auto ||
        tnspec_setup $tnsbin board $board

    run_flash || {
        pr_err_b "[ERROR] Flashing failed." "run_flash legacy: "
        exit 1
    }
}

_choose_hook_flash_main_legacy() {
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
        [[ -n "$board_default" ]] && {
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

run_flash() {
    local _run_flash_post=0

    _set_cmdline

    pr_info_b "====================================================================="
    pr_info__ "PRODUCT_OUT"
    echo "$PRODUCT_OUT"
    pr_info ""
    pr_info__ "FLASH COMMAND (Run from $PRODUCT_OUT)"
    echo "${cmdline[*]}"
    if [ "${#cmdline_post[@]}" != "0" ]; then
        pr_info ""
        pr_info__ "POST FLASH COMMAND (Run from $PRODUCT_OUT)"
        echo "${cmdline_post[*]}"
        _run_flash_post=1
    fi
    pr_info_b "====================================================================="


    # return if dryrun is set
    [ "$_dryrun" == "1" ] && {
        flash_status "completed"
        return
    }

    flash_status "flashing"

    # Execute command
    eval ${cmdline[@]} || {
        flash_status "aborted"
        return 1
    }

    [ "$_run_flash_post" == "1" ] && {
        eval ${cmdline_post[@]} || {
            flash_status "aborted"
            return 1
        }
    }

    flash_status "completed"
    return 0
}

run_flash_alternate() {
    local tns="$1"
    local method="$2"

    local flash_ops="erase_partitions update_partitions"
    [ "$(getprop arg_secure)" != "--securedev" ] || [ "${cur_specid##*.}" == "diag" ] &&
        flash_ops+=" update_nct"
    local op

    tnspec_preload $tns

    pr_info_b "··················································"
    pr_info_b "FLASHING METHOD: $method"
    pr_info_b "··················································"
    for op in $flash_ops; do
        local part file _v v="$(tnspec_get_sw $tns.$method.$op)"
        pr_cyan_b "▮ PROCESSING '$op'"
        case $op in
            update_partitions)
                update_partitions $v
                ;;
            erase_partitions)
                if [ -n "$v" ]; then
                  for _v in $v; do
                      part=${_v%:*}
                      pr_info   "[$part] Erasing '$_v'" "  ▸ "
                      [ "$_dryrun" == "1" ] &&
                          pr_info "part_erase $part " "--- " || {
                              part_erase $part || {
                                  pr_err_b "[$part] Failed."  "  ▸ "
                                  exit 1
                              }
                          }

                      pr_info_b "[$part] OK!"  "  ▸ "
                  done
                else
                    pr_info "Nothing to erase" "  ▸ "
                fi
                ;;
            update_nct)
                [ "$v" != "false" ] && {
                    pr_info   "[NCT] Flashing '$tnsbin'" "  ▸ "
                    [ "$_dryrun" == "1" ] && pr_info "nct_write $tnsbin" "--- " ||
                                             nct_write $tnsbin
                    pr_info_b "[NCT] OK!"  "  ▸ "
                } || pr_info "[NCT] Skipped" "  ▸ "
                ;;
        esac
    done
    pr_cyan_b "▮ DONE! Rebooting your device."
    [ "$_dryrun" != "1" ] && _reboot
    pr_info_b "··················································"
}

update_partitions()
{
    local v info cmd

    for v
    do
        local part=${v%:*} file=${v#*:} filelist

        if [ -n "$file" ] ; then
            readarray -t filelist <<< "$(tnspec_get_sw $specid.$file)"
            if [ -z "$var_types" ]; then
                # Legacy
                # Check if "file" var is of signed_vars entries.
                _in_array $file $sw_var_signed_vars && {
                    [ "${#filelist[@]}" == "2" ] && {
                        [ "$_mode" == "1" ] \
                        && file=${filelist[1]} || file=${filelist[0]}
                    }
                } || file="${filelist[*]}"
            else
                file=$(getcond $file filelist)
            fi
        fi

        if [ -z "$file" ] ; then
            pr_err "[$part] Ignored (missing file)" "  ▸ "
            continue
        fi

        if ! [ -f "$file" ] ; then
            # It's a critical error when the file name is defined,
            # but doesn't exist.
            pr_err "[$part] Aborted ('$file' doesn't exist)" "  ▸ "
            exit 1
        fi

        if _in_array $part $sw_var_oem_signed; then
            info="Signing and flashing" cmd=part_signwrite
        else
            info="Flashing" cmd=part_write
        fi

        pr_info   "[$part] $info '$file'" "  ▸ "
        if [ "$_dryrun" == "1" ] ; then
            pr_info "$cmd $part $file" "--- "
        else
            if ! $cmd $part $file ; then
                pr_err_b "[$part] Failed."  "  ▸ "
                exit 1
            fi
            pr_info_b "[$part] OK!"  "  ▸ "
        fi
    done
}

###############################################################################
# EEPROM Board Info Reader
###############################################################################
#
# eeprom_read <eeprom_module> <outfile>
# - Reads board information from EEPROM
#
# eeprom_module type of EEPROM to be read
# outfile Name of the file to store EEPROM dump in
#
# Communicates with the device to read board information such as serial number,
# mac address, asset tracker fields and so on
#
eeprom_read()
{
    [ "$_dryrun" == "1" ] && {
        pr_warn "Dry-run. Dumping command only." "eeprom_read: "
        nodeps=1 dumponly=$_dryrun _tegraflash "dump eeprom $1 $2"
        return 1
    }

    [ "$flash_driver" == "tegraflash" ] && {
        local reboot_cmd
        [ "$(getprop chip)" == "0x19" ] && {
            is_mb2_applet=1
            reboot_cmd="; reboot recovery"
        }
        nodeps=1 _tegraflash "dump eeprom $1 $2 $reboot_cmd" || {
            pr_err "Error while reading EEPROM" "eeprom_read: "
            exit 1
        }
    }
}

###############################################################################
# ram info dump
#
# dump ram/storage info, use to select ram config
#
###############################################################################
ram_info_dump()
{
    # ram info dump is only supported after 0x19
    [ "$(getprop chip)" != "0x19" ] && {
        return
    }

    [ "$flash_driver" == "tegraflash" ] && {
        is_mb2_applet=1
        nodeps=1 dumponly=$_dryrun _tegraflash "dump eeprom boardinfo cvm.bin" > $TNSPEC_OUTPUT || {
            pr_err "Error while dumping cvm boardinfo" "ram_info_dump: "
            exit 1
        }

        pr_info "dump platform chip and storage info" "ram_info_dump: "
        [ "$_dryrun" == "1" ] && return

        local tegrarcm_bin=$(getprop tegrarcm)
        $(nvbin $tegrarcm_bin) $instance --oem platformdetails chip chip_info.bin  > $TNSPEC_OUTPUT || {
            pr_err "Error while dumping platform chip info" "ram_info_dump: "
            exit 1
        }

        $(nvbin $tegrarcm_bin) $instance --oem platformdetails storage storage_info.bin > $TNSPEC_OUTPUT || {
            pr_err "Error while dumping platform storage info" "ram_info_dump: "
            exit 1
        }

        $(nvbin $tegrarcm_bin) $instance --reboot recovery
    }
}

###############################################################################
# ODM Override
#
# [args]
# $* - a list of odm override pairs.
#   Accepted Formats:
#    1. "odm_data_mnemonic:value"
#       'value' can be a key in the odm table or a numeric value (hex allowed)
#       e.g. "wdt:enable" or "wdt:1" or "wdt:0x1"
#    2. "bit_hi:bit_lo:numeric_value"
#       e.g. "15:0:0x3333"
###############################################################################
odm_override() {
    local list="$*"

    local _odmtable="$(tnspec_get_sw $specid.odmtable)"

    [ -z "$_odmtable" ] &&
        pr_warn "odmtable is missing. odm_override support is limited." "odm_override: "

    pr_info "Processing ODMDATA override: $list" "odm_override: "
    pr_info "Current odmdata: $odmdata" "odm_override: "
    odmdata=$(_odm_override_core $odmdata "$list") || {
        pr_err "Error while processing $*" "odm_override: "
        exit 1
    }
    pr_info "NEW odmdata: $odmdata" "odm_override: "
}

_odm_override_core() {
python - <<EOF
import sys
import json
odm=int('$1', 0)
overrider='$2'.split(' ')
odmtable='''$_odmtable'''

_m = 0xffffffff
try:
    if odmtable:
        odmtable = json.loads(odmtable)
except Exception as e:
    print >> sys.stderr, "JSON format error:", repr(e)
    sys.exit(1)

def mask(hi, lo):
    w = (hi - lo + 1)
    return (((1 << w) -1) << lo) & _m

for o in overrider:
    _o = o.split(':')
    if len(_o) == 2:
        if not odmtable:
            print >> sys.stderr, "odmtable must be defined for processing %s" % o
            sys.exit(1)
        bit = odmtable[_o[0]]['bit'].split(':')
        try:
            val = int(_o[1], 0)
        except:
            try:
                val = int(odmtable[_o[0]]['val'][_o[1]], 0)
            except:
                print >> sys.stderr, "%s is not defined for %s in odmtable" % (_o[1], _o[0])
                sys.exit(1)
    elif len(_o) == 3:
        bit = _o[:2]
        val = int(_o[2], 0)
    hi, lo = map(lambda x: int(x, 0), bit)
    m = mask(hi, lo)
    odm = ((odm & (~m & _m)) | ((val << lo) & m)) & _m
print "0x%08x" % (odm & _m)
EOF
}

###############################################################################
# Partition Read/Write Functions
###############################################################################
part_read() {
    local p=$1 f=$2 post_read
    [ -e "$f" ] && _su rm -f $f 2> /dev/null
    [ -e "$f.tmp" ] && _su rm -f $f.tmp 2> /dev/null

    [ "$flash_driver" == "tegraflash" ] && {
        [ "$(getprop chip)" == "0x19" ] && {
            is_mb2_applet=1
            post_read=";reboot recovery"
        }
        _tegraflash "read $p $f.tmp $post_read" > $TNSPEC_OUTPUT || return 1
    } || {
        _nvflash  "--read $p $f.tmp" > $TNSPEC_OUTPUT || return 1
    }
    cp $f.tmp $f || return 1
    _su rm $f.tmp
}

part_write() {
    local p=$1 f=$2
    [ -e "$f" ] || {
        pr_err "'$f' doesn't exist." "part_write: "
        exit 1
    }

    [ "$flash_driver" == "tegraflash" ] && {
        [ "$(getprop chip)" == "0x19" ] && is_mb2_applet=1
        _tegraflash "write $p $f" > $TNSPEC_OUTPUT || return 1
    } || {
        _nvflash "--download $p $f" > $TNSPEC_OUTPUT || return 1
    }
}

part_signwrite() {
    local p=$1 f=$2

    [ -e "$f" ] || {
        pr_err "'$f' doesn't exist." "part_signwrite: "
        exit 1
    }

    [ "$flash_driver" != "tegraflash" ] && {
        pr_err "only tegraflash supported." "part_signwrite: "
        exit 1
    }

    [ "$(getprop chip)" == "0x19" ] && is_mb2_applet=1
    _tegraflash "signwrite $p $f" > $TNSPEC_OUTPUT || return 1
}

part_erase() {
    local p=$1
    [ "$flash_driver" == "tegraflash" ] && {
        _tegraflash "erase $p" > $TNSPEC_OUTPUT || return 1
    } || {
        pr_err "Erasing partitions is supported for tegraflash only."
        exit 1
    }
}

###############################################################################
# Flashing Status
###############################################################################
flash_status() {
    [ "$flash_interface" == "legacy" ] || [ -z "$workspace" ] && return

    # Return status if no argument is passed
    if [ "$#" == "0" ]; then
        [ -e "$workspace/status" ] && cat $workspace/status || echo ""
        return
    fi
    echo "$1" > $workspace/status
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

# Display prompt and loop until valid input is given
_choose() {
    _shell_is_interactive || { "error: _choose needs an interactive shell" ; exit 2 ; }
    local query="$1"                   # $1: Prompt text
    local -a choices=($2)              # $2: Valid input values
    local _input
    local selected=''
    while [[ -z $selected ]] ; do
        read -p "$query" _input
        [ -n "$_choose_hook" ] && $_choose_hook $_input || {
            _input=${input_hooked:-$_input}

            if ! _in_array "$_input" "${choices[@]}"; then
                pr_err "'$_input' is not a valid choice." "selection: "
                pr_err "$choices[*]" "selection: "
            else
                selected=$_input
            fi
        }
        query=${query_hooked:-$query}
    done
    eval "$3=$selected"
    # If predefined input is invalid, return error
    _in_array "$selected" "${choices[@]}"
}

_use_color() { [ -z "$_nocolor" ] && _shell_is_interactive ; }

# Pretty prints ($2 - optional header)
pr_info() {
    if  _use_color; then
        echo -e "\033[95m$2\033[0m\033[${_cl}37m$1\033[0m"
    else
        echo "$2$1"
    fi
}
pr_info_b() {
    _cl="1;" pr_info "$1" "$2"
}
pr_info__() {
    _cl="4;" pr_info "$1" "$2"
}
pr_ok() {
    if _use_color; then
        echo -e "\033[95m$2\033[0m\033[${_cl}92m$1\033[0m"
    else
        echo "$2$1"
    fi
}
pr_ok_b() {
    _cl="1;" pr_ok "$1" "$2"
}
pr_ok__() {
    _cl="4;" pr_ok "$1" "$2"
}
pr_ok_bl() {
    if  _use_color; then
        echo -e "\033[95m$2\033[0m\033[${_cl}94m$1\033[0m"
    else
        echo "$2$1"
    fi
}
pr_cyan() {
    if _use_color; then
        echo -e "\033[95m$2\033[0m\033[${_cl}96m$1\033[0m"
    else
        echo "$2$1"
    fi
}
pr_cyan_b() {
    _cl="1;" pr_cyan "$1" "$2"
}
pr_warn() {
    if  _use_color; then
        echo -e "\033[95m$2\033[0m\033[${_cl}93m$1\033[0m"
    else
        echo "$2$1"
    fi
}
pr_warn_b() {
    _cl="1;" pr_warn "$1" "$2"
}
pr_err() {
    if _use_color; then
        echo -e "\033[95m$2\033[0m\033[${_cl}91m$1\033[0m"
    else
        echo "$2$1"
    fi
}
pr_err_b() {
    _cl="1;" pr_err "$1" "$2"
}

nvbin() {
    if [[ -n $_nosudo ]]; then
        echo "$HOST_BIN/$1"
    else
        echo "sudo $HOST_BIN/$1"
    fi
}

_tegraflash() {
    local chip=$(getprop chip) applet=${sw_var_rcm:-$(getprop applet)} secure=$(getprop arg_secure)
    local _skip_uid blob_params params cmd_params

    [ "$skip_uid" == "1" ] && {
        skip_uid=0
        _skip_uid="--skipuid"
    }

    params="$_skip_uid --chip $chip $instance --applet $applet $secure"
    if [ -n "$sw_var_bct" ] && [ -n "$sw_var_rcm_bct" ]; then
        params+=" --rcm_bct $sw_var_rcm_bct --bct $sw_var_bct"
    fi

    if [ "$is_mb2_applet" == "1" ]; then
        is_mb2_applet=0
        params+=" --soft_fuses $(getprop soft_fuses)"
        blob_params="--bin \"mb2_applet $(getprop mb2_applet)\""
        cmd_params="--cmd \"$1\""
    else
        local bl=${sw_var_ebt:-$(getprop bl)}
        local odmdata=${_odmdata:-${sw_var_odm:-"0x9c000"}}
        local bct_configs cfg_config mts_blob bl_blob bpmp_blob secos_blob eks_blob

        # odm overide
        [ -n "$sw_var_odm_override" ] && {
            odm_override $sw_var_odm_override
        }

        [ "$(getprop version)" == "2" ] && {
            bl_blob="mb2_bootloader $(getprop bl_mb2)"
            [ "$nodeps" == "1" ] && {
                [ "$chip" == "0x18" ] && mts_blob="mts_preboot $sw_var_preboot; mts_bootpack $sw_var_bootpack;"
                [ "$chip" == "0x19" ] && {
                    mts_blob="mts_preboot $sw_var_preboot; mts_mce $sw_var_mce; mts_proper $sw_var_proper;"
                    spe_blob="spe_fw $sw_var_spe"
                }
                bl_blob="bootloader_dtb $sw_var_dtb; mb2_bootloader $(getprop bl_mb2);"
                bpmp_blob="bpmp_fw $sw_var_bpmp; bpmp_fw_dtb $sw_var_dtb_bpmp;"
                secos_blob="tlk $sw_var_sec_os;"
                eks_blob="eks $sw_var_eks"
                bct_configs="$(_get_bct_config_tegraflash_v2)"
            }
            blob_params="--bins \"$spe_blob $mts_blob $bl_blob $bpmp_blob $secos_blob $eks_blob\""
        }

        params+=" --bl $bl $bct_configs $cfg_config --odmdata $odmdata"
        cmd_params="--cmd \"$1\""
    fi

    local _cmd="$(nvbin tegraflash.py) $params $blob_params $cmd_params"

    pr_info_b "$_cmd" "_tegraflash: "
    [ "$dumponly" == "1" ] && return 0
    eval "$_cmd"
}

_nvflash() {
    local _resume _skip_uid

    [ "$resume_mode" == "1" ] && {
       _resume="--resume"
    }
    resume_mode=1

    [ "$skip_uid" == "1" ] && {
       _skip_uid="--skipcid"
       skip_uid=0
    }
    local _cmd="$(nvbin nvflash) $_resume $(getprop arg_blob) $@ --bl $(getprop bl) $instance $_skip_uid"
    pr_info_b "$_cmd" "_nvflash: "

    eval "$_cmd"
}

# su
_su() {
    if [[ -n $_nosudo ]]; then
        $@
    else
        sudo $@
    fi
}

# convert unix path to windows path
_os_path()
{
    if [ "$OSTYPE" == "cygwin" ]; then
        echo \'$(cygpath -w $1)\'
    else
        echo $1
    fi
}

# check if we have required tools
check_tools_system()
{
    # system tools
    local tools=(python diff sha256sum wc curl)
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
            pr_info "  >> $cygbin -q -P <packages>"
            pr_info ""
            pr_info "To find packages: https://cygwin.com/cgi-bin2/package-grep.cgi"
        fi
        return 1
    fi

    return 0
}

# Check NVIDIA tools
check_tools_nvidia()
{
    local tools t
    if [ "$flash_driver" == "tegraflash" ]; then
        tools="tegraflash.py $(getprop tegradevflash) part_table_ops.py $(getprop tegrarcm)"
    else
        tools="nvflash"
    fi
    for t in $tools; do
        [ -x "$HOST_BIN/$t" ] || {
            pr_err "'$HOST_BIN/$t' not found." "check_tools_nvidia: "
            exit 1
        }
    done
}

# Check additional dependencies
check_deps()
{
    local deps d
    if [ "$flash_driver" == "tegraflash" ]; then
        # TODO: clean up this, only check those needed for platform detect
        [ ! -n "$board" ] && deps="$(getprop applet)"
        [ "$(getprop version)" == "2" ] && deps="$deps $(getprop bl_mb2)"
    else
        deps=""
    fi
    for d in $deps; do
        [ -f "$d" ] || {
            pr_err "'$d' not found." "check_deps: "
            exit 1
        }
    done
}

# Set all needed parameters
_set_cmdline_nvflash() {
    # Minimum battery charge required.
    if [[ -n $sw_var_minbatt ]]; then
        pr_err "*** MINIMUM BATTERY CHARGE REQUIRED = $sw_var_minbatt% ***" "_set_cmdline_nvflash: "
        local minbatt="--min_batt $sw_var_minbatt"
    fi

    # Disable display if specified (to prevent flashing failure due to low battery)
    if [[ "$sw_var_no_disp" == "true" ]]; then
        local nodisp="--odm limitedpowermode"
        pr_warn "Display on target is disabled while flashing to save power." "_set_cmdline_nvflash: "
    fi

    # Set ODM data, BCT and CFG files (with fallback defaults)
    local odmdata=${_odmdata:-${sw_var_odm:-"0x9c000"}}
    local bctfile=${sw_var_bct:-"bct.cfg"}
    local cfgfile=${sw_var_cfg:-"flash.cfg"}
    local dtbfile=$sw_var_dtb

    # if flashing fused devices, lock bootloader. (bit 13)
    [ "$_mode" != "0" ] && {
        odm_override 13:13:1
    }

    # Set NCT option
    if [ "$sw_var_skip_nct" != "true" ]; then
        tnspec nct dump nct -n $tnsbin > $tnsbin.txt
        nct="--nct $tnsbin.txt"
    else
        pr_warn "$specid doesn't use NCT." "_set_cmdline_nvflash: "
        nct=""
    fi

    # Set SKU ID, MTS settings. default to empty
    local skuid=${_skuid:-${sw_var_sku:-""}}
    [[ -n $skuid ]] && skuid="-s $skuid"
    [[ -n $sw_var_preboot ]] && local preboot="--preboot $sw_var_preboot"
    [[ -n $sw_var_bootpack ]] && local bootpack="--bootpack $sw_var_bootpack"

    # XXX: remove this. use sw_var_dtb directly
    # Update DTB filename if not previously set.
    # in mobile sanity testing (Bug 1439258)
    if [ -z "$dtbfile" ] && _shell_is_interactive; then
        dtbfile=$(grep dtb ${PRODUCT_OUT}/$cfgfile | cut -d "=" -f 2)
        pr_info "Using the default product dtb file $_dtbfile" "_set_cmdline_nvflash: "
    else
        # Default used in automated sanity testing is "unknown"
        dtbfile=${dtbfile:-"unknown"}
    fi

    cmdline=(
        _nvflash
        $minbatt
        --bct $bctfile
        --setbct
        --odmdata $odmdata
        --configfile $cfgfile
        --dtbfile $dtbfile
        --create
        $skuid
        $nct
        $nodisp
        $preboot
        $bootpack
    )

    [ "$flash_interface" == "legacy" ] || [ "$sw_var_skip_nct" == "true" ] && {
        cmdline=(${cmdline[@]} --go)
        return
    }

    # cmdline_post
    _set_cmdline_xlate_flash_post
    cmdline_post=(_nvflash "--download NCT $tnsbin $flash_post --go")
}

# Set all needed parameters for Automotive boards.
_set_cmdline_automotive() {
    # Parse bootburn commandline
    local burnflash_cmd=
    if [ -n "$sw_var_sku" ]; then
        burnflash_cmd="$burnflash_cmd -S $sw_var_sku"
    fi

    if [ -n "$sw_var_dtb" ]; then
        burnflash_cmd="$burnflash_cmd -d $sw_var_dtb"
    fi

    local odmdata=${_odmdata:-${sw_var_odm}}
    if [ -n "$odmdata" ]; then
        burnflash_cmd="$burnflash_cmd -o $odmdata"
    fi

    if [[ $_modem ]]; then
        if [[ $_modem -lt 0x1F ]]; then
            # Set odmdata in bootburn.sh
            burnflash_cmd="$burnflash_cmd -m $_modem"
        else
            pr_warn "Unknown modem reference [$_modem]. Unchanged odmdata." "_mdm_odm: "
        fi
    fi

    cmdline=(
        $PRODUCT_OUT/bootburn.sh
        -a
        -r ram0
        -Z zlib
        $burnflash_cmd
        $instance
        ${commands[@]}
    )
}

# Iterates over cfg_override read from tnspec and updates partition table
_update_partitions_cfg_override() {
    local part file list filename
    local e

    [ -n "$sw_var_cfg_override" ] && {
        for e in $sw_var_cfg_override
        do
            part=${e%:*}
            file=${e#*:}

            [ -n "$file" ] && {
                readarray -t filename <<< "$(tnspec_get_sw $specid.$file)"
                if [ -z "$var_types" ]; then
                    # Legacy
                    # Check if "file" var is of signed_vars entries.
                    _in_array $file $sw_var_signed_vars && {
                        [ "${#filename[@]}" == "2" ] && {
                            [ "$_mode" == "1" ] \
                            && filename=${filename[1]} || filename=${filename[0]}
                        }
                    } || filename="${filename[*]}"
                else
                    filename=$(getcond $file filename)
                fi
            }
            list="$list$part:$filename "
        done
        _update_partitions $list
    }
}

# Updates partition table with partition:filename passed as argument
_update_partitions() {
    local list="$@"

    [ -f "$sw_var_cfg" ] || {
        pr_err "'$sw_var_cfg' is not found." "_update_partitions: "
        exit 1
    }

    [ -n "$list" ] && {
        local cfg_tmp=$(basename $sw_var_cfg)
        cfg_tmp=${tmpws:+$tmpws/}${cfg_tmp%%.*}.xml.updated
        [ "$sw_var_cfg" != "$cfg_tmp" ] && cp $sw_var_cfg $cfg_tmp
        pr_info_b "Updating $sw_var_cfg -> $cfg_tmp" "_update_partitions: "
        pr_info "$list" "_update_partitions: "
        $(nvbin part_table_ops.py) -i $cfg_tmp -o $cfg_tmp $list || {
            pr_err "Failed to patch '$sw_var_cfg' using $list" "_update_partitions: " >&2
            exit 1
        }
        sw_var_cfg=$cfg_tmp
    }
}

_find_fuse_bypass_xml() {
    # tnspec might define fuse_bypass xml file
    local _f=${sw_var_fusebypass:-fuse_bypass.xml}
    # fuse_bypass xml file is either in the current directory or under 'data'
    [ -f "$_f" ] && {
        echo $_f
        return
    }
    _f=data/$_f
    [ -f "$_f" ] && {
        echo $_f
        return
    }
}

_set_cmdline_tegraflash() {
    # Construct cmd
    local cmd=$(getprop flash_cmd)

    # Convert flash_post to a command string
    _set_cmdline_xlate_flash_post

    if [ "$flash_interface" == "legacy" ] ; then
        # legacy flash cmdline
        [ -n "$BOARD" ] && cmd=$sw_var_cmd_gvs || cmd=$sw_var_cmd

        local partitions_to_update="DTB:$sw_var_dtb RP1:$sw_var_dtb"

        # fused device
        if [ "$_mode" == "1" ]; then
            if [ -n "$sw_var_sufix" ]; then
                local signedbits=("cboot.bin.signed" "nvtboot.bin.signed" "nvtboot_cpu.bin.signed" "tos.img.signed"\
                                  "warmboot.bin.signed" "rcm_1_signed.rcm")
                for bit in ${signedbits[@]}; do
                    [ -f "$PRODUCT_OUT/$bit$sw_var_sufix" ] && cp $PRODUCT_OUT/$bit$sw_var_sufix $PRODUCT_OUT/$bit
                done
                partitions_to_update="$partitions_to_update UDA:userdata.img"
            fi

            if [ -n "$_parts_path" ]; then
                local eks_file_name="EKS_bak.bin"
                [ -e "${_parts_path}/eks_bak.bin" ] && eks_file_name="eks_bak.bin"
                cmd="secureflash; write FCT $_parts_path/fct_bak.bin; write NCT ${_parts_path}/nct_bak.bin; write EKS ${_parts_path}/$eks_file_name"
            else
                cmd=$(echo $cmd | sed -e 's/flash/secureflash/g')
            fi
        fi

        _update_partitions "$partitions_to_update"

    else
        cmd="$cmd $flash_post reboot"

        # Update NCT (TNSPEC) partition
        _update_partitions "NCT:$tnsbin"
    fi

    local skuid=${_skuid:-${sw_var_sku:-""}}
    local _fbxml=$(_find_fuse_bypass_xml)
    if [[ -n $skuid && -n $_fbxml && $_mode -eq 0 ]]; then
        cmd="parse fusebypass $_fbxml $skuid; $cmd"

        # Regardless of the location of fuse_bypass.xml, tegraflash expects the
        # base name (fuse_bypass.bin) without any path name. Confusing, but
        # it's how it's implemented so far.

        local _fbbin=${_fbxml%.*}.bin
        local fbfile="--fb $_fbbin"
        # Update fusebypass partition for non-fused devices when skuid is
        # defined and if fuse_bypass.xml exists
        # t186 products need update fusebypass partition
        [ "$(getprop chip)" == "0x18" ] && {
            _update_partitions "fusebypass:fuse_bypass.bin"
        }
    fi

    if [[ -n $cmd ]]; then
        cmd="--cmd \"$cmd\""
    fi

    local odmdata=${_odmdata:-${sw_var_odm:-"0x9c000"}}

    # if bl_disable_lock is true, do not lock bootloader
    if [ "$sw_var_bl_disable_lock" != "true"  ];then
        if [ "$_mode" != "0" ]; then
            odm_override 13:13:1
        fi
    fi

    # odm overide
    [ -n "$sw_var_odm_override" ] && {
        odm_override $sw_var_odm_override
    }

    local skipsanitize

    # Set skipsanitize option
    if [ "$sw_var_skip_sanitize" != "true" ]; then
        skipsanitize=""
    else
        skipsanitize="--skipsanitize"
    fi

    _update_partitions_cfg_override

    case $(getprop version) in
        2)
            _set_cmdline_tegraflash_v2
            ;;
        *)
            _set_cmdline_tegraflash_v1
            ;;
    esac

    cmdline=($(nvbin tegraflash.py) ${cmdline[@]})

    if [ "$skip_uid" == "1" ]; then
        cmdline=(${cmdline[@]} --skipuid)
        skip_uid=0
    fi
}
_set_cmdline_tegraflash_v1() {
    local bctfile=${sw_var_bct:-"bct_cboot.cfg"}
    if [ "$_mode" != "0" ] && [ "${bctfile##*.}" != "bct" ]; then
        [[ $bctfile == *.cfg ]] && bctfile=${bctfile%.cfg}.bct || {
            pr_err "bctfile '$bctfile' doesn't end with .cfg" "_set_cmdline_tegraflash: "
            exit 1
        }
    fi

    cmdline=(
        --bct $bctfile
        --bl ${sw_var_ebt:-$(getprop bl)}
        --cfg $sw_var_cfg
        --odmdata $odmdata
        --bldtb $sw_var_dtb
        --chip $(getprop chip)
        --applet ${sw_var_rcm:-$(getprop applet)}
        --nct $tnsbin
        $skipsanitize
        $cmd
        $fbfile
        $instance
        $(getprop arg_secure)
        )

    if [ -n "$sw_var_rcm_bct" ]; then
        pr_ok "RCM mode uses BCT file: $sw_var_rcm_bct"
        cmdline=(--rcm_bct $sw_var_rcm_bct ${cmdline[@]})
    fi
}

_get_bct_config_tegraflash_v2() {
    local bct_configs=""
    [ -n "$sw_var_bct_configs_sdram" ]  && bct_configs+="--sdram_config $sw_var_bct_configs_sdram "
    [ -n "$sw_var_bct_configs_misc" ]   && bct_configs+="--misc_config $sw_var_bct_configs_misc "
    [ -n "$sw_var_bct_configs_misc_cold_boot" ]   && bct_configs+="--misc_cold_boot_config $sw_var_bct_configs_misc_cold_boot "
    [ -n "$sw_var_bct_configs_pinmux" ] && bct_configs+="--pinmux_config $sw_var_bct_configs_pinmux "
    [ -n "$sw_var_bct_configs_scr" ]    && bct_configs+="--scr_config $sw_var_bct_configs_scr "
    [ -n "$sw_var_bct_configs_scr_cold_boot" ] && bct_configs+="--scr_cold_boot_config $sw_var_bct_configs_scr_cold_boot "
    [ -n "$sw_var_bct_configs_pmc" ]    && bct_configs+="--pmc_config $sw_var_bct_configs_pmc "
    [ -n "$sw_var_bct_configs_pmic" ]   && bct_configs+="--pmic_config $sw_var_bct_configs_pmic "
    [ -n "$sw_var_bct_configs_br_cmd" ] && bct_configs+="--br_cmd_config $sw_var_bct_configs_br_cmd "
    [ -n "$sw_var_bct_configs_prod" ]   && bct_configs+="--prod_config $sw_var_bct_configs_prod "
    [ -n "$sw_var_bct_configs_dev_params" ] && bct_configs+="--dev_params $sw_var_bct_configs_dev_params "
    [ -n "$sw_var_bct_configs_soft_fuses" ] && bct_configs+="--soft_fuses $sw_var_bct_configs_soft_fuses "
    [ -n "$sw_var_bct_configs_gpioint" ]    && bct_configs+="--gpioint_config $sw_var_bct_configs_gpioint "
    [ -n "$sw_var_bct_configs_uphy" ]       && bct_configs+="--uphy_config $sw_var_bct_configs_uphy "
    [ -n "$sw_var_bct_configs_device" ]     && bct_configs+="--device_config $sw_var_bct_configs_device "
    [ -n "$sw_var_bct_configs_deviceprod" ]     && bct_configs+="--deviceprod_config $sw_var_bct_configs_deviceprod "

    echo $bct_configs
}

_set_cmdline_tegraflash_v2() {
    # BCT Configs
    local bct_configs="$(_get_bct_config_tegraflash_v2)"

    local bl_blob="bootloader_dtb $sw_var_dtb; mb2_bootloader $(getprop bl_mb2);"

    local chip=$(getprop chip)

    # MTS/SPE Bins
    local mts_blob spe_blob
    [ "$chip" == "0x18" ] && {
        mts_blob="mts_preboot $sw_var_preboot; mts_bootpack $sw_var_bootpack;"
    }
    [ "$chip" == "0x19" ] && {
        mts_blob="mts_preboot $sw_var_preboot; mts_mce $sw_var_mce; mts_proper $sw_var_proper;"
        spe_blob="spe_fw $sw_var_spe;"
    }

    local bpmp_blob="bpmp_fw $sw_var_bpmp; bpmp_fw_dtb $sw_var_dtb_bpmp;"

    local secos_blob="tlk $sw_var_sec_os;"
    local eks_blob="eks $sw_var_eks"

    cmdline=(
        $bct_configs
        --bl  $(getprop bl)
        --bin \"$mts_blob $spe_blob $bl_blob $bpmp_blob $secos_blob $eks_blob\"
        --cfg $sw_var_cfg
        --odmdata $odmdata
        --chip $(getprop chip)
        --applet $(getprop applet)
        $cmd
        $fbfile
        $instance
        $(getprop arg_secure)
        )

}

_set_cmdline_xlate_flash_post() {
    local x tmp
    for x in "${flash_post[@]}"; do
        local part_file=($x)
        local part=${part_file[0]}
        local file=${part_file[1]}

        # copy fiels with abs path to $OUT for nvflash/cygwin
        [ "$flash_driver" == "tegraflash" ] && {
            if _in_array $part $sw_var_oem_signed; then
                tmp+="signwrite $part $file;"
            else
                tmp+="write $part $file;"
            fi
        } || {
            # flash_driver == "nvflash"
            [ "$OSTYPE" == "cygwin" ] && {
                # Make sure the target file is copied to $OUT
                local base=$(basename $file)
                [ "$file" != "$base" ] && {
                    pr_warn "[Cygwin NVFLASH WAR] Copying $file to $PRODUCT_OUT/$part.$cid" "_set_cmdline_xlate_flash_post: "
                    cp -fL $file $PRODUCT_OUT/$part.$cid || {
                        pr_err "Failed to copy $file to $PRODUCT_OUT/$part.$cid" "_set_cmdline_xlate_flash_post: "
                        exit 1
                    }
                    x="${part_file[0]} $part.$cid"
                }
            }
            tmp+="--download $x "
        }
    done
    flash_post="$tmp"
}

_set_cmdline() {
    if [ "$flash_driver" == "tegraflash" ]; then
        _set_cmdline_tegraflash
    elif [ "$flash_driver" == "bootburn" ]; then
        _set_cmdline_automotive
    else
        _set_cmdline_nvflash
    fi
}

parse_commands() {
    # Handle --instance for now. Do not handle other commands yet.
    commands=()
    local cmds=($@)
    local c breaker i=0
    for c;
    do
        ((i++))
        case $c in
        --) breaker=1
            ;;
        --instance)
            breaker=1
            pr_warn "--instance <instance> will be deprecated. Please use -i <instance>." "flash.sh: " >&2
            local _i="${cmds[i]}"
            if [ -z "$_i" ];then
                pr_err "--instance requires an argument" "flash.sh: " >&2
                usage
                exit 1
            else
                _instance=$_i
            fi
            ;;
        *)
            [ -z "$breaker" ] && commands+=($c)
            ;;
        esac
    done
}

###############################################################################
# Main code
###############################################################################

# convert args into an array
args_a=( "$@" )

ROOT_PATH=$PWD

HOST_BIN="${HOST_BIN:-$ROOT_PATH}"

[ ! -f "$HOST_BIN/tegraflash.py" ] && {
    [ -n "$(find $ROOT_PATH/../../../ -maxdepth 1 -type d -name "host")" ] && {
         HOST_BIN=$ROOT_PATH/../../../host/linux-x86/bin
    } || HOST_BIN=$ROOT_PATH/../../../../host/linux-x86/bin
}

if [ -n "${NOCOLOR}" ]; then
    _nocolor=1
fi

if [ -z "$PRODUCT_OUT" ]; then
    PRODUCT_OUT=$ROOT_PATH
fi

# Convert HOST_BIN, PRODUCT_OUT and TNSPEC_WORKSPACE to absolute paths
_optional_dirs="TNSPEC_WORKSPACE"

for p in "HOST_BIN" "PRODUCT_OUT" "TNSPEC_WORKSPACE"
do
    _p="$(eval echo \"\$$p\")"
    ! _in_array $p $_optional_dirs && [ ! -d "$_p" ] && {
        pr_err "'$p=$_p' doesn't appear to be a directory" "flash.sh: "
        exit 1
    }
    [ -z "$_p" ] && continue
    case $_p in
        /*) eval $p=\"$_p\" ;;
        *)  eval $p=\"$PWD/$_p\" ;;
    esac
done

# Optional arguments
while getopts "no:s:t:c:m:b:w:i:P:pfvuhdCOFXN" OPTION
do
    case $OPTION in
    h) usage
        exit 0
        ;;
    d)  _dryrun=1;
        ;;
    c)  _chip_version=${OPTARG};
        ;;
    f)  _fused=1;
        ;;
    m) _modem=${OPTARG};
        ;;
    n) _nosudo=1;
        ;;
    i) _instance=${OPTARG};
        ;;
    o) _odmdata=${OPTARG};
        ;;
    p) _parts_path="${HOME}/.partsback";
       ;;
    s) _skuid=${OPTARG};
        _peek=${args_a[(( OPTIND - 1 ))]}
        if [ "$_peek" == "forcebypass" ]; then
            _skuid="$_skuid $_peek"
            shift
        fi
        ;;
    t) _tnspec_json_file=${OPTARG};
        ;;
    u) _unattended=1
        ;;
    v) _verbose=1
        ;;
    b) _battery=${OPTARG};
        ;;
    w) _watchdog=${OPTARG};
        ;;
    C) _nocolor=1
        ;;
    O) _offline=1;
        ;;
    P) _parts_path=${OPTARG};
        ;;
    F) _force=1;
        ;;
    X) _exp=1;
        pr_info   ""
        pr_info   ""
        pr_info_b "**********************************************************"
        pr_info   ""
        pr_info   " -X is no longer needed to invoke the new flash interface."
        pr_info   ""
        pr_info_b "**********************************************************"
        pr_info   ""
        pr_info   ""
        ;;
    N) _no_track=1;
        ;;
    esac
done

tnspec_bin=$PRODUCT_OUT/tnspec.py

if [ ! -x "$tnspec_bin" ]; then
    pr_err "Error: $tnspec_bin doesn't exist or is not executable." "TNSPEC: " >&2
    exit 1
fi

if ! check_tools_system; then
    pr_err "Error: missing required tools." "flash.sh: " >&2
    exit 1
fi

# Detect OS
case $OSTYPE in
    cygwin)
        _nosudo=1
        umask 0000
        ;;
    linux*|Linux*)
        umask 0002
        ;;
    *)
        pr_err "unsupported OS type $OSTYPE detected" "flash.sh: "
        exit 1
        ;;
esac

shift $(($OPTIND - 1))
parse_commands $@

# Set globals
! _shell_is_interactive && _unattended=1
[[ -n "$_instance" ]] && {
    instance="--instance $_instance"
}

# If BOARD is set, use it as predefined board name
[[ -n $BOARD ]] && board="$BOARD"

# Debug
[ "$_verbose" == "1" ] &&
    TNSPEC_OUTPUT=${TNSPEC_OUTPUT:-/dev/stderr} ||
    TNSPEC_OUTPUT=${TNSPEC_OUTPUT:-/dev/null}

[ ! -w "$TNSPEC_OUTPUT" ] && {
    pr_warn "$TNSPEC_OUTPUT doesn't have write access." "TNSPEC_OUTPUT: "
    exit 1
}

(cd $PRODUCT_OUT && flash_main)
