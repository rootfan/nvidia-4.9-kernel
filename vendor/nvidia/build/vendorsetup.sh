###############################################################################
#
# Copyright (c) 2010-2018, NVIDIA CORPORATION.  All rights reserved.
#
# NVIDIA CORPORATION and its licensors retain all intellectual property
# and proprietary rights in and to this software, related documentation
# and any modifications thereto.  Any use, reproduction, disclosure or
# distribution of this software and related documentation without an express
# license agreement from NVIDIA CORPORATION is strictly prohibited.
#
###############################################################################

function _gethosttype()
{
    H=`uname`
    if [ "$H" == Linux ]; then
        HOSTTYPE="linux-x86"
    fi

    if [ "$H" == Darwin ]; then
        HOSTTYPE="darwin-x86"
        export HOST_EXTRACFLAGS="-I$(gettop)/vendor/nvidia/tegra/core-private/include"
    fi
}

function _getnumcpus ()
{
    # if we happen to not figure it out, default to 2 CPUs
    NUMCPUS=2

    _gethosttype

    if [ "$HOSTTYPE" == "linux-x86" ]; then
        NUMCPUS=`cat /proc/cpuinfo | grep processor | wc -l`
    fi

    if [ "$HOSTTYPE" == "darwin-x86" ]; then
        NUMCPUS=`sysctl -n hw.activecpu`
    fi
}

use_old_flash_tool()
{
    local target=$(get_build_var TARGET_PRODUCT)
    local ret=0

    case "$target" in
        *) ;;
    esac

    echo $ret
}

function get_flash_tool()
{
    local flash="flash.sh"

    if [ $(use_old_flash_tool) -eq 1 ]; then
        flash="flash_legacy.sh"
    fi

    echo $flash
}

function war_copy_tnspec_tool()
{
    local suffix=""
    local T=$(gettop)
    local PRODUCT_OUT=$(get_build_var PRODUCT_OUT)

    if [ $(use_old_flash_tool) -eq 1 ]; then
        suffix="_legacy"
    fi

    cp -u $T/vendor/nvidia/tegra/core/tools/tnspec$suffix/tnspec${suffix}.py $PRODUCT_OUT
}

function _karch()
{
    # Some boards (eg. exuma) have diff ARCHes between
    # userspace and kernel, denoted by TARGET_ARCH and
    # TARGET_ARCH_KERNEL, whichever non-null is picked.
    local arch=$(get_build_var TARGET_ARCH_KERNEL)
    test -z $arch && arch=$(get_build_var TARGET_ARCH)
    echo $arch
}

function _default_kpath()
{
    T=$(gettop)
    local kpath=$(get_build_var KERNEL_PATH)
    kpath=${kpath:-$T/kernel/kernel-4.4}
    echo "$kpath"
}

function _defconfig()
{
    local CFG="tegra_android_defconfig"
    echo "$CFG"
}

function _kbuild_options()
{
    local TARGET_BUILD_TYPE=$(get_build_var TARGET_BUILD_TYPE)
    local TARGET_BUILD_VARIANT=$(get_build_var TARGET_BUILD_VARIANT)
    local SRC=${KBUILD_KERNEL_PATH:-$(_default_kpath)}
    local KERNEL_FOLDER=$(basename $SRC)
    local NV_BUILD_KERNEL_OPTIONS=()

    # keep this for T124 kernel builds
    NV_BUILD_KERNEL_OPTIONS+=(tlk)

    if [ "$NVIDIA_KERNEL_COVERAGE_ENABLED" == "1" ]; then
        NV_BUILD_KERNEL_OPTIONS+=(gcov)
    fi

    if [[ "$KERNEL_FOLDER" == "kernel-4.4" ]];then
        NV_BUILD_KERNEL_OPTIONS+=(4.4)
    elif [[ "$KERNEL_FOLDER" == "kernel-4.9" ]];then
        NV_BUILD_KERNEL_OPTIONS+=(4.9)
    elif [[ "$KERNEL_FOLDER" == "kernel-4.14" ]];then
        NV_BUILD_KERNEL_OPTIONS+=(4.14)
    elif [[ "$KERNEL_FOLDER" == "kernel-shield-3.10" ]];then
        NV_BUILD_KERNEL_OPTIONS+=(shield)
    fi

    if [[ "$TARGET_BUILD_TYPE" == "release" && "$TARGET_BUILD_VARIANT" == "user" ]]; then
        NV_BUILD_KERNEL_OPTIONS+=(production)
    fi

    echo "${NV_BUILD_KERNEL_OPTIONS[@]}"
}

function _is_knext()
{
    # success exit code for "t186ref_int_knext"/"vcm31t186ref_int_k"
    case "$TARGET_PRODUCT" in
        *_int_knext) return 0 ;;
        *)           return 1 ;;
    esac
}

# absolute kernel intermediates path
function _kout_path()
{
    T=$(gettop)
    local SRC=$(_default_kpath)
    local KOUT=$T/$(get_build_var TARGET_OUT_INTERMEDIATES)/KERNEL/$(basename $SRC)
    echo "$KOUT"
}

function kbuild()
{
    T=$(gettop)
    if [ ! "$T" ]; then
        echo "Couldn't locate the top of the tree. Try setting TOP." >&2
        return 1
    fi

    local BUILD_OPTIONS=${KBUILD_OPTIONS:-$(_kbuild_options)}
    local KOUT="${KBUILD_KOUT:-$(_kout_path)}"
    local OUTDIR="${KBUILD_OUTDIR:-$T/$(get_build_var PRODUCT_OUT)}"
    local TEGRA_VER=${KBUILD_TEGRA_VER:-$(get_build_var TARGET_TEGRA_VERSION)}
    local TOOLCHAIN_NAME=aarch64

    if [[ "$1" =~ "NV_BUILD_KERNEL_OPTIONS=" ]];then
        BUILD_OPTIONS="${1#NV_BUILD_KERNEL_OPTIONS=}"
        shift 1
    fi

    if [[ ! "t210 t186 t194" =~ $TEGRA_VER ]]; then
        echo "unsupported TARGET_TEGRA_VERSION:$TEGRA_VER" >&2
        return 1
    fi

    _getnumcpus


    # run cov-build command for zImage build command if Coverity is enabled.
    local COVBUILD_CMD=
    if [[ ${NV_KERNEL_COVERITY_ENABLED} == 1 ]] && [[ "$1" == zImage || "$1" == modules ]]; then
        local COVERITY_CONFIG=${KOUT}/coverity/configs/coverity_config.xml
        if [[ ! -e ${COVERITY_CONFIG} ]]; then
            mkdir -p $(dirname ${COVERITY_CONFIG})
            for toolchain in arm-cortex_a15-linux-gnueabi-gcc arm-cortex_a15-linux-gnueabi-g++ \
                             arm-none-eabi-gcc arm-none-eabi-ar arm-none-eabi-g++ arm-eabi-gcc \
                             aarch64-linux-android-gcc armv7a-hardfloat-linux-gnueabi Linux-ARMv7-gnueabihf \
                             aarch64-unknown-linux-gnu-gcc aarch64-gnu-linux-gcc; do
                    cov-configure --config $COVERITY_CONFIG  --comptype gcc --compiler $toolchain --template 2>&1;
            done
        fi
        COVBUILD_CMD="cov-build --config ${COVERITY_CONFIG} --dir ${KOUT}/coverity/emit"
    fi
    ${COVBUILD_CMD} make -C $T -j$NUMCPUS -l$NUMCPUS  -f $T/kernel-build/make/Makefile.kernel \
      NV_OUTDIR="$KOUT"                                                       \
      NV_BUILD_KERNEL_ARCH_DIR="${KBUILD_ARCH:-$(_karch)}"                    \
      NV_BUILD_KERNEL_DTBS_INSTALL="$OUTDIR"                                  \
      NV_BUILD_KERNEL_MODULES_INSTALL="$KOUT"                                 \
      NV_BUILD_KERNEL_CONFIG_NAME="${KBUILD_KERNEL_DEFCONFIG:-$(_defconfig)}" \
      NV_BUILD_KERNEL_OPTIONS="$BUILD_OPTIONS"                                \
      NV_BUILD_KERNEL_TOOLCHAIN_NAME="$TOOLCHAIN_NAME" $*
}

# usage: kcovcheck [options] FILE1 FILE2 ...
#     options: any option accepted by cov-run-desktop.
#     FILE: C file path(full or relative path to $TOP/kernel or $TOP)
function kcovcheck()
{
    if [[ ${NV_KERNEL_COVERITY_ENABLED} != 1 ]]; then
        echo "Coverity is not enabled" >&2
        return 1
    fi

    local T=$(gettop)
    local _kout="${KBUILD_KOUT:-$(_kout_path)}"
    local _src=${KBUILD_KERNEL_PATH:-$(_default_kpath)}
    local _coverity_config=${_kout}/coverity/configs/coverity_config.xml
    local _karch=-"${KBUILD_ARCH:-$(_karch)}"
    local _tegra_ver=${KBUILD_TEGRA_VER:-$(get_build_var TARGET_TEGRA_VERSION)}
    local _toolchain_name=aarch64
    local _defconfig=-${KBUILD_KERNEL_DEFCONFIG:-$(_defconfig)}
    _security="-default"
    local _k4dot4=
    if [[ "${_defconfig}" =~ "tegra21_android_defconfig" ]] && \
       [[ "${_src}" =~ "kernel-4.4" ]]; then
           _k4dot4="-4.4"
    fi
    # e.g: aarch64-arm64-tegra21_android_defconfig-tlk-4.4
    local _stream_name="${_toolchain_name}${_karch}${_defconfig}${_security}${_k4dot4}"
    local _cov_host=${NV_COV_HOST:-"sccovlinb"}
    local _cov_port=${NV_COV_PORT:-"8080"}
    local _cov_ak_file="${HOME}/.coverity/authkeys/kcovcheck-${_cov_host}-${_cov_port}"
    # create authkey file
    if [[ ! -e "${_cov_ak_file}" ]]; then
        echo "create auth-key to server ${_cov_host}:${_cov_port}:"
        local _user
        read -p "User Name[${USER}]:" _user
        if [[ -z ${_user} ]]; then
            _user=${USER}
        fi
        cov-run-desktop --create-auth-key --auth-key-file "${_cov_ak_file}" \
                        --host ${_cov_host} --port ${_cov_port} --user "${_user}" \
                        --stream "${_stream_name}"
        if [[ $? != 0 ]]; then
            echo "cov-run-desktop can not create auth-key" >&2
            rm -f "${_cov_ak_file}"
            return 1
        fi
        echo "Auth-key for server ${_cov_host}:${_cov_port} is created at ${_cov_ak_file}"

    fi
    # sanity checks
    if [[ ! -f ${_coverity_config} ]] || [[ ! -d ${_kout}/coverity/emit ]]; then
        echo "No Coverity enabled kernel build, please:" >&2
        echo "1. make sure Coverity tool is synced to $P4ROOT/sw/mobile/tools/coverity/coverity_8.1.0" >&2
        echo "2. clean build kernel with: rm -rf $OUT/obj/KERNEL then mp bootimage or ksetup && krebuild" >&2
        return 1

    fi

    # if no file is specified, get all modified kernel files.
    declare -a _cfiles
    if [[ $(echo "$@" | sed 's/$T\///g'|sed 's/\ /\n/g' |grep -c ".*\.c$") -eq 0 ]]; then
        for d in $(find $T/kernel -mindepth 1 -maxdepth 1 -type d -printf "%P "); do
            for f in $(cd $T/kernel/$d && git status --porcelain |egrep "^[\? MRCA].*\.c$" |sed "s/^[\? MRCA]*\s\+/$d\//g"); do
                # check if $f is get compiled:
                _obj=$(dirname ${_kout})/${f/%.c/.o}
                if [[ -f ${_obj} ]]; then
                    _cfiles+=($f)
                fi
            done
        done
    fi
    # cov-run-desktop will generate some log files under $(pwd), always keep these logs under ${HOME}/.coverity
    (cd ${HOME}/.coverity &&
    cov-run-desktop --reference-snapshot latest          \
                    --sort file                          \
                    --config ${_coverity_config}         \
                    --dir ${_kout}/coverity/emit         \
                    --stream ${_stream_name}             \
                    --host ${_cov_host}                  \
                    --port ${_cov_port}                  \
                    --auth-key-file "${_cov_ak_file}"    \
                    "$@" ${_cfiles[@]})
}

# "Usage: ksetup [defconfig]", default defconfig will be used if no defconfig is provided.
function ksetup()
{
    T=$(gettop)
    if [ ! "$T" ]; then
        echo "Couldn't locate the top of the tree. Try setting TOP." >&2
        return 1
    fi

    # init global variables here to reduce get_build_var call
    # it will speed up other k* commands.
    _getnumcpus
    KBUILD_KERNEL_PATH="$(_default_kpath)"
    KBUILD_OUTDIR="$T/$(get_build_var PRODUCT_OUT)"
    KBUILD_KOUT="$(_kout_path)"
    KBUILD_HOSTOUT="$T/$(get_build_var HOST_OUT)"
    KBUILD_TARGET_OUT="$T/$(get_build_var TARGET_OUT_VENDOR)"
    KBUILD_TARGET_OUT_ODM="$T/$(get_build_var TARGET_OUT_ODM)"

    KBUILD_ARCH=$(_karch)
    KBUILD_OPTIONS="$(_kbuild_options)"
    KBUILD_TEGRA_VER=$(get_build_var TARGET_TEGRA_VERSION)
    KBUILD_PRODUCT_USES_ARM_TF_MONITOR=$(get_build_var PRODUCT_USES_ARM_TF_MONITOR)
    KBUILD_BOARD_SUPPORT_SIMULATION=$(get_build_var BOARD_SUPPORT_SIMULATION)
    KBUILD_BOARD_SUPPORT_KERNEL_COMPRESS=$(get_build_var BOARD_SUPPORT_KERNEL_COMPRESS)

    if [ $# -lt 1 ] ; then
        KBUILD_KERNEL_DEFCONFIG="$(_defconfig)"
        kbuild silentoldconfig
    elif [[ -f "$KBUILD_KERNEL_PATH/arch/$KBUILD_ARCH/configs/$1" ]]; then
        KBUILD_KERNEL_DEFCONFIG="$1"
        kbuild silentoldconfig
    elif [[ "$1" =~ "menuconfig" ]]; then
        if [[ ! -f "$KBUILD_KOUT/.config" ]]; then
            KBUILD_KERNEL_DEFCONFIG="$(_defconfig)"
            kbuild silentoldconfig
        fi
        kconfig
    elif [[ "$1" =~ "savedefconfig" ]]; then
        if [[ ! -f "$KBUILD_KOUT/.config" ]]; then
            KBUILD_KERNEL_DEFCONFIG="$(_defconfig)"
            kbuild silentoldconfig
        fi
        shift 1
        ksavedefconfig $*
    else
        echo "Invalid ksetup argument. Usage:" >&2
        echo "ksetup [DEFCONFIG_NAME | menuconfig | savedefconfig]" >&2
    fi
}

function kconfig()
{
    kbuild menuconfig
}

# Usage: ksavedefconfig [defconfig] [kernelpath]
function ksavedefconfig()
{
    T=$(gettop)
    if [ ! "$T" ]; then
        echo "Couldn't locate the top of the tree. Try setting TOP." >&2
        return 1
    fi

    local SRC=${KBUILD_KERNEL_PATH:-$(_default_kpath)}
    local defconfig=
    if [ $# -lt 1 ] ; then
        defconfig=${KBUILD_KERNEL_DEFCONFIG:-$(_defconfig)}
    else
        defconfig=$1
    fi

    if [ $# -gt 1 ] ; then
        SRC="$2"
    fi

    if [ ! -d "$SRC" ] ; then
        echo "$SRC not found."
        return 1
    fi

    local KARCH=${KBUILD_ARCH:-$(_karch)}
    local KOUT="${KBUILD_KOUT:-$(_kout_path)}"
    local DEFCONFIG_PATH="$SRC/arch/$KARCH/configs"

    # make a backup of the current configuration
    cp $KOUT/.config $KOUT/.config.backup

    kbuild savedefconfig && cp -v $KOUT/defconfig $DEFCONFIG_PATH/${defconfig}
    # restore configuration from backup
    rm $KOUT/.config
    mv $KOUT/.config.backup $KOUT/.config
}

# only try to build simulation image if all prerequisites exist
# sim-image depends on Andriod droidcore build target.
# all of below checked prerequisites should be built as side-effect of droidcore.
function build_simimage()
{
    local support_sim=${KBUILD_BOARD_SUPPORT_SIMULATION:-$(get_build_var BOARD_SUPPORT_SIMULATION)}
    local product_out=${KBUILD_OUTDIR:-$T/$(get_build_var PRODUCT_OUT)}

    if [[ "${support_sim}" != "true" ]]; then
        echo "No simulation support for this board." >&2
        return 0
    fi

   # these files are built as side-effect of droidcore target.
    if [[ ! -f ${product_out}/kernel-configuration-name.txt ]] || \
       [[ ! -f ${product_out}/kernel-simdts-name.txt ]]; then
           return 0
    fi

    T=$(gettop)
    read kdefconfig < ${product_out}/kernel-configuration-name.txt
    read ksimdts < ${product_out}/kernel-simdts-name.txt

    local secure_os_image=
    local tegra_ver=${KBUILD_TEGRA_VER:-$(get_build_var TARGET_TEGRA_VERSION)}
    local sim_dts_file="${KBUILD_KERNEL_PATH:-$(_default_kpath)}/arch/arm64/boot/dts/${ksimdts}"

    if [[ ! -f ${sim_dts_file} ]]; then
        return 0
    fi

    declare -a boot_wrapper_build_args=()
    if [[ ${tegra_ver} == "t186" ]]; then
        boot_wrapper_build_args+=(
                NV_BUILD_KERNEL64_SIM_DTS=${ksimdts}
        )
    fi

    secure_os_image=${product_out}/trusty_sim_lk.bin
    if [[ ! -f ${secure_os_image} ]]; then
        return 0
    fi
    boot_wrapper_build_args+=(
            NV_BUILD_KERNEL64_SECURE_OS=${secure_os_image}
    )

    local secure_monitor_image=
    secure_monitor_image=${product_out}/trusty_sim_atf.bin
    if [[ ! -f ${secure_monitor_image} ]]; then
        return 0
    fi

    boot_wrapper_build_args+=(
            NV_BUILD_KERNEL64_EL3_MONITOR=${secure_monitor_image}
    )

    # ramdisk file
    local ramdisk_file=${product_out}/full_filesystem.img
    if [[ ${tegra_ver} != "t186" ]]; then
        ramdisk_file=${product_out}/nvtest_ramdisk.img
    fi
    if [[ ! -f ${ramdisk_file} ]]; then
        return 0
    fi
    boot_wrapper_build_args+=(
            NV_BUILD_KERNEL64_INITRD=${ramdisk_file}
    )

    kbuild ${boot_wrapper_build_args[@]} build-qt

    local kout="${KBUILD_KOUT:-$(_kout_path)}"
}

function krebuild()
{
    T=$(gettop)
    if [ ! "$T" ]; then
        echo "Couldn't locate the top of the tree. Try setting TOP." >&2
        return 1
    fi

    local SRC=${KBUILD_KERNEL_PATH:-$(_default_kpath)}
    if [ ! -d "$SRC" ] ; then
        echo "$SRC not found."
        return 1
    fi

    _getnumcpus

    if [ -n "$*" ];then
        kbuild $*
        return $?
    fi
    local KOUT="${KBUILD_KOUT:-$(_kout_path)}"
    if [ ! -f $KOUT/.config ];then
        echo "Could not find $KOUT/.config, please run ksetup $(_defconfig) at first" >&2
        return 1
    fi

    local OUTDIR="${KBUILD_OUTDIR:-$T/$(get_build_var PRODUCT_OUT)}"
    local HOSTOUT=${KBUILD_HOSTOUT:-$T/$(get_build_var HOST_OUT)}
    local TARGET_OUT="${KBUILD_TARGET_OUT:-$T/$(get_build_var TARGET_OUT_VENDOR)}"
    local TARGET_OUT_ODM="${KBUILD_TARGET_OUT_ODM:-$T/$(get_build_var TARGET_OUT_ODM)}"
    local MKBOOTIMG=$HOSTOUT/bin/mkbootimg
    local KERNEL_COMPRESS="${KBUILD_BOARD_SUPPORT_KERNEL_COMPRESS:-$(get_build_var BOARD_SUPPORT_KERNEL_COMPRESS)}"
    local TEGRA_VER=${KBUILD_TEGRA_VER:-$(get_build_var TARGET_TEGRA_VERSION)}

    local KARCH=${KBUILD_ARCH:-$(_karch)}

    if [[ $KARCH = "arm64" ]]; then
        local KERNEL_TOOLCHAIN=$T/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9/bin/aarch64-linux-android-
        local ZIMAGE=$KOUT/arch/$KARCH/boot/Image
        if [[ $KERNEL_COMPRESS = "gzip" ]]; then
            ZIMAGE=$KOUT/arch/$KARCH/boot/zImage
        fi
    else
        local KERNEL_TOOLCHAIN=$T/prebuilts/gcc/linux-x86/arm/arm-eabi-4.8/bin/arm-eabi-
        local ZIMAGE=$KOUT/arch/$KARCH/boot/zImage
    fi

    local RAMDISK=$OUTDIR/ramdisk.img

    if [ ! -f "$RAMDISK" ]; then
        if [ -z "$TARGET_OUT" ];then
            echo "Couldn't find $RAMDISK. Try setting TARGET_PRODUCT." >&2
        else
            echo "Couldn't find $RAMDISK. Try building it by mp ramdisk at first." >&2
        fi
        return 1
    fi


    kbuild zImage && kbuild modules && kbuild dtbs
    local ERR=$?

    if [ $ERR -ne 0 ] ; then
        return $ERR
    fi

    mkdir -p $TARGET_OUT/lib/modules
    mkdir -p $TARGET_OUT_ODM/lib/modules
    find $KOUT/.. ! -path "*kernel_space_tests*"  ! -path "*tegrawatch*"  \
         -name "*.ko" | xargs cp -u -t $TARGET_OUT/lib/modules/
    find $TARGET_OUT/lib/modules/ -name "*.ko" -exec ${KERNEL_TOOLCHAIN}strip \
         --strip-debug {} \;
    if [[ ${TEGRA_VER} == "t186" ]]; then
        local KERNEL_MODULES_ODM_LIST="$T/device/nvidia-t18x/t186/lkm/odm.list"
    else
        local KERNEL_MODULES_ODM_LIST="$T/device/nvidia/platform/t210/lkm/odm.list"
    fi
    if [ -f $KERNEL_MODULES_ODM_LIST ]; then
        for file in `cat $KERNEL_MODULES_ODM_LIST`; do
            mv $TARGET_OUT/lib/modules/$file $TARGET_OUT_ODM/lib/modules/ | true;
        done
    else
        echo "Couldn't find odm.list for the ODM type kernel modules."
    fi

    cp -u $KOUT/arch/$KARCH/boot/dts/*.dtb $KOUT/arch/$KARCH/boot/dts/*.dtbo $OUT

    if [[ $KARCH =~ "arm64" && -f ${OUT}/full_filesystem.img && -f ${ZIMAGE} ]]; then
        build_simimage || true
    fi

    if [[ $KARCH = "arm64" && $KERNEL_COMPRESS = "lz4" ]]; then
        local LZ4C=$HOSTOUT/bin/lz4c
        local COMPRESSED_KERNEL=$KOUT/arch/$KARCH/boot/zImage.lz4
        $LZ4C -c1 -l -f $ZIMAGE $COMPRESSED_KERNEL
        ZIMAGE=$COMPRESSED_KERNEL
    fi

    if [ ! -f "$MKBOOTIMG" ]; then
        echo "Couldn't find $MKBOOTIMG to build boot.img. Try building it by mp mkbootimg." >&2
        return 1
    else
        $MKBOOTIMG --kernel $ZIMAGE --ramdisk $RAMDISK --output $OUTDIR/boot.img && \
        echo "$OUTDIR/boot.img created successfully."
    fi
}

function buildsparse()
{
    #build kernel and kernel modules with Sparse
    SPARSE=$(which sparse)
    if [ ! "$SPARSE" ]; then
        echo "Couldn't locate the sparse." >&2
        echo "For more details see :" >&2
        echo "https://wiki.nvidia.com/wmpwiki/index.php/System_SW/Static_Analysis/sparse" >&2
        return 1
    fi

    local BUILD_OPTIONS="${KBUILD_OPTIONS:-$(_kbuild_options)} sparse"
    # TODO: only support full source tree check..
    kbuild NV_BUILD_KERNEL_OPTIONS="$BUILD_OPTIONS" Image
}

function build_single_dtb()
{
    local DTS_NAME="$1"
    local DTB_NAME=${DTS_NAME/.dts/.dtb}
    local KARCH=${KBUILD_ARCH:-$(_karch)}
    local KOUT="${KBUILD_KOUT:-$(_kout_path)}"
    local DTB_FILE=$KOUT/arch/$KARCH/boot/dts/$DTB_NAME
    local SIGNER=$(get_build_var HOST_OUT)/bin/boot_signer
    local VERITY_PK8=$TOP/build/target/product/security/verity.pk8
    local VERITY_X509=$TOP/build/target/product/security/verity.x509.pem
    local support_avb=$(get_build_var BOARD_AVB_ENABLE)

    echo $DTB_NAME
    kbuild $DTB_NAME
    if [ "$support_avb" ]; then
        $TOP/$AVBTOOL add_hash_footer \
        --image $DTB_FILE \
        --partition_size $(get_build_var BOARD_DTB_PARTITION_SIZE) \
        --partition_name kernel-dtb \
        --algorithm $(get_build_var BOARD_AVB_ALGORITHM) \
        --key $TOP/$(get_build_var BOARD_AVB_KEY_PATH)
    else
        $SIGNER /boot $DTB_FILE $VERITY_PK8 $VERITY_X509 $DTB_FILE
    fi

    cp -u $DTB_FILE $OUT
    echo "$OUT/$DTB_NAME created successfully."
}

function builddtb()
{
    local SRC=${KBUILD_KERNEL_PATH:-$(_default_kpath)}
    local SIGNER=$(get_build_var HOST_OUT)/bin/boot_signer
    local VERITY_PK8=$TOP/build/target/product/security/verity.pk8
    local VERITY_X509=$TOP/build/target/product/security/verity.x509.pem
    local support_avb=$(get_build_var BOARD_AVB_ENABLE)

    if [ ! -d "$SRC" ] ; then
        echo "kernel SRC not found."
        return 1
    fi
    local KARCH=${KBUILD_ARCH:-$(_karch)}
    local KOUT="${KBUILD_KOUT:-$(_kout_path)}"

    kbuild dtbs
    local DTB_FILES=$KOUT/arch/$KARCH/boot/dts/*.dtb
    local DTBO_FILES=$KOUT/arch/$KARCH/boot/dts/*.dtbo
    for DTB_FILE in $DTB_FILES $DTBO_FILES;
    do
        if [ "$support_avb" ]; then
            $TOP/external/avb/avbtool add_hash_footer \
            --image $DTB_FILE \
            --partition_size $(get_build_var BOARD_DTB_PARTITION_SIZE) \
            --partition_name kernel-dtb \
            --algorithm $(get_build_var BOARD_AVB_ALGORITHM) \
            --key $TOP/$(get_build_var BOARD_AVB_KEY_PATH)
        else
            $SIGNER /boot $DTB_FILE $VERITY_PK8 $VERITY_X509 $DTB_FILE
        fi
    done
    cp -pvu $DTB_FILES $DTBO_FILES $OUT
}

function buildsysimg()
{
    local OUT=$(get_build_var OUT)
    local TARGET_OUT=$OUT/system
    local systemimage_intermediates=$OUT/obj/PACKAGING/systemimage_intermediates
    $TOP/build/tools/releasetools/build_image.py $TARGET_OUT $systemimage_intermediates/system_image_info.txt $systemimage_intermediates/system.img
    cp $systemimage_intermediates/system.img $OUT/
    echo "$OUT/system.img created successfully."
}

function buildall()
{
    #build kernel and kernel modules
    krebuild

    #build board's device tree blob (dtb)
    builddtb

    #create system.img
    buildsysimg
}

# allow us to override Google defined functions to apply local fixes
# see: http://mivok.net/2009/09/20/bashfunctionoverrist.html
_save_function()
{
    local oldname=$1
    local newname=$2
    local code=$(declare -f ${oldname})
    eval "${newname}${code#${oldname}}"
}

#
# Unset variables known to break or harm the Android Build System
#
#  - CDPATH: breaks build
#    https://groups.google.com/forum/?fromgroups=#!msg/android-building/kW-WLoag0EI/RaGhoIZTEM4J
#
_save_function m  _google_m
function m()
{
    CDPATH= _google_m $*
}

_save_function mm _google_mm
function mm()
{
    CDPATH= _google_mm $*
}

function mp()
{
    _getnumcpus

    local PLATFORM_IS_AFTER_O_MR0=$(get_build_var PLATFORM_IS_AFTER_O_MR0)
    if [ "$PLATFORM_IS_AFTER_O_MR0" == "1" ]; then
        m -j$NUMCPUS $*
    else
        m -j$NUMCPUS -l$NUMCPUS  $*
    fi
}

function mmp()
{
    _getnumcpus

    local PLATFORM_IS_AFTER_O_MR0=$(get_build_var PLATFORM_IS_AFTER_O_MR0)
    if [ "$PLATFORM_IS_AFTER_O_MR0" == "1" ]; then
        mm -j$NUMCPUS $*
    else
        mm -j$NUMCPUS -l$NUMCPUS  $*
    fi
}

function fboot()
{
    T=$(gettop)

    if [ ! "$T" ]; then
        echo "Couldn't locate the top of the tree. Try setting TOP." >&2
        return 1
    fi
    local INTERMEDIATES=$(get_build_var TARGET_OUT_INTERMEDIATES)
    local OUTDIR=$(get_build_var PRODUCT_OUT)
    local HOST_OUTDIR=$(get_build_var HOST_OUT)

    local ZIMAGE=$(_kout_path)/arch/$(_karch)/boot/zImage
    local RAMDISK=$T/$OUTDIR/ramdisk.img
    local FASTBOOT=$T/$HOST_OUTDIR/bin/fastboot
    local vendor_id=${FASTBOOT_VID:-"0x955"}

    if [ ! "$FASTBOOT" ]; then
        echo "Couldn't find $FASTBOOT." >&2
        return 1
    fi

    if [ $# != 0 ] ; then
        CMD=$*
    else
        if [ ! -f  "$ZIMAGE" ]; then
            echo "Couldn't find $ZIMAGE. Try setting TARGET_PRODUCT." >&2
            return 1
        fi
        if [ ! -f "$RAMDISK" ]; then
            echo "Couldn't find $RAMDISK. Try setting TARGET_PRODUCT." >&2
            return 1
        fi
        CMD="-i $vendor_id boot $ZIMAGE $RAMDISK"
    fi

    echo "sudo $FASTBOOT $CMD"
    (eval sudo $FASTBOOT $CMD)
}

function fflash()
{
    T=$(gettop)

    if [ ! "$T" ]; then
        echo "Couldn't locate the top of the tree. Try setting TOP." >&2
        return 1
    fi
    local OUTDIR=$(get_build_var PRODUCT_OUT)
    local HOST_OUTDIR=$(get_build_var HOST_OUT)

    local BOOTIMAGE=$T/$OUTDIR/boot.img
    local SYSTEMIMAGE=$T/$OUTDIR/system.img
    local FASTBOOT=$T/$HOST_OUTDIR/bin/fastboot

    local DTBIMAGE=$T/$OUTDIR/$(get_build_var TARGET_KERNEL_DT_NAME).dtb
    local vendor_id=${FASTBOOT_VID:-"0x955"}

    if [ ! "$FASTBOOT" ]; then
        echo "Couldn't find $FASTBOOT." >&2
        return 1
    fi

    if [ $# != 0 ] ; then
        CMD=$*
    else
        if [ ! -f  "$BOOTIMAGE" ]; then
            echo "Couldn't find $BOOTIMAGE. Check your build for any error." >&2
            return 1
        fi
        if [ ! -f "$SYSTEMIMAGE" ]; then
            echo "Couldn't find $SYSTEMIMAGE. Check your build for any error." >&2
            return 1
        fi
        CMD="-i $vendor_id flash system $SYSTEMIMAGE flash boot $BOOTIMAGE"
        if [ "$DTBIMAGE" != "" ] && [ -f "$DTBIMAGE" ]; then
            CMD=$CMD" flash dtb $DTBIMAGE"
        fi
        CMD=$CMD" reboot"
    fi

    echo "sudo $FASTBOOT $CMD"
    (sudo $FASTBOOT $CMD)
}

function _flash()
{
    local PRODUCT_OUT=$(get_build_var PRODUCT_OUT)
    local HOST_OUT=$(get_build_var HOST_OUT)

    # _nvflash_sh uses the 'bsp' argument to create BSP flashing script
    if [[ "$1" == "bsp" ]]; then
        T="\$(pwd)"
        local FLASH_SH="$T/$PRODUCT_OUT/flash.sh \$@"
        shift
    else
        T=$(gettop)
        local FLASH_SH=$T/vendor/nvidia/build/$(get_flash_tool)
    fi

    local cmdline=(
        PRODUCT_OUT=$T/$PRODUCT_OUT
        HOST_BIN=\${HOST_BIN:-$T/$HOST_OUT/bin}
        $FLASH_SH
        $@
    )

    echo ${cmdline[@]}
}

function flash()
{
    eval $(_flash $@)
}

# Print out a shellscript for flashing BSP or buildbrain package
# and copy the core script to PRODUCT_OUT
function _nvflash_sh()
{
    T=$(gettop)
    local PRODUCT_OUT=$(get_build_var PRODUCT_OUT)
    local HOST_OUT=$(get_build_var HOST_OUT)

    # Vibrante Android requires own flash script.
    local NV_REQUIRES_EMBEDDED_FOUNDATION=$(get_build_var NV_REQUIRES_EMBEDDED_FOUNDATION)
    if [[ "${NV_REQUIRES_EMBEDDED_FOUNDATION}" != true ]]; then
        cp -u $T/vendor/nvidia/build/$(get_flash_tool) $PRODUCT_OUT/flash.sh

        # WAR - tnspec.py can be missing in some packages.
        war_copy_tnspec_tool
    fi

    # Unified flashing command
    local cmd='#!/bin/bash

# enable globbing in case it has already been turned off
set +f

pkg_filter=android_*_os_image-*.tgz
pkg=$(echo $pkg_filter)
pkg_dir="_${pkg/%.tgz}"
host_bin="$HOST_OUT/bin"

if [[ "$pkg" != "$pkg_filter" && -f $pkg && ! -d "$pkg_dir" ]]; then
    echo "Extracting $pkg...."
    mkdir $pkg_dir
    (cd $pkg_dir && tar xfz ../$pkg)
    find $pkg_dir -maxdepth 2 -type f -exec cp -u {} $PRODUCT_OUT \;

    # copy host bins
    find $pkg_dir -path \*$host_bin\* -type f -exec cp -u {} $host_bin \;

    # check if system_gen.sh was used
    x=$(basename $pkg_dir/android_*_os_image*)
    [ -d "$x" ] && {
        echo "************************************************************"
        echo
        echo "WARNING:"
        echo "    Looks like \"system_img.gen\" was used."
        echo "    \"./flash.sh\" is the only script needed for flashing."
        echo
        echo "************************************************************"
    }
fi
'
    cmd=${cmd//\$PRODUCT_OUT/$PRODUCT_OUT}
    cmd=${cmd//\$HOST_OUT/$HOST_OUT}

    echo "$cmd"
    if [[ ! "${NV_REQUIRES_EMBEDDED_FOUNDATION}" == true ]]; then
        echo "($(_flash bsp))"
    fi
}

function adbserver()
{
    f=$(pgrep adb)
    if [ $? -ne 0 ]; then
        ADB=$(which adb)
        echo "Starting adb server.."
	sudo ${ADB} start-server
    fi
}

function nvlog()
{
    T=$(gettop)
    if [ ! "$T" ]; then
	echo "Couldn't locate the top of the tree.  Try setting TOP." >&2
	return 1
    fi
    adbserver
    adb logcat | $T/vendor/nvidia/build/asymfilt.py
}

function stayon()
{
    adbserver
    adb shell "svc power stayon true && echo main >/sys/power/wake_lock"
}

function _tnspec_which()
{
    T=$(gettop)
    local PRODUCT_OUT=$T/$(get_build_var PRODUCT_OUT)

    local tnspec_spec=$PRODUCT_OUT/tnspec.json
    local tnspec_spec_public=$PRODUCT_OUT/tnspec-public.json

    if [ -f $tnspec_spec ]; then
        echo $tnspec_spec
    elif [ -f $tnspec_spec_public ]; then
        echo $tnspec_spec_public
    elif [ ! -f $tnspec_spec_public ]; then
        echo "Error: tnspec.json doesn't exist. $tnspec_spec $tnspec_spec_public" >&2
    fi
}

function _tnspec()
{
    T=$(gettop)
    local PRODUCT_OUT=$T/$(get_build_var PRODUCT_OUT)

    local tnspec_bin=$PRODUCT_OUT/tnspec.py

    # return nothing if tnspec tool or spec file is missing
    if [ ! -x $tnspec_bin ]; then
        echo "Error: tnspec.py doesn't exist or is not executable. $tnspec_bin" >&2
        return
    fi

    $tnspec_bin $*
}

function tnspec()
{
    _tnspec $* -s $(_tnspec_which)
}

function tntest()
{
    T=$(gettop)
    $T/vendor/nvidia/tegra/core/tools/tntest/tntest.sh $@
}

function kupdate()
{
    OVERRIDE_SW="kernel.update_nct=false" flash -O auto kernel
}

# XXX: Remove this function.
function flash_sn()
{
    echo "Deprecated. Use 'flash tnspec' command instead."
}

# Add Nvidia .PHONY build goals to Kati parse time make goals list
# NOTE: if you add a goal to the build then you *MUST* update this list too!
_nvidia_parse_time_goals=(
    dev
    kernel-tests
    nvidia-tests
    nvidia-tests-automation
    nv-vbmetaimage
    otapackage
    showcommands
    sim-image
)
export PARSE_TIME_MAKE_GOALS="${_nvidia_parse_time_goals[@]}"
unset _nvidia_parse_time_goals

# Enable "ninja + PR#1139: ninja as GNU make jobserver client" mode
export USE_NINJA_JOBSERVER_CLIENT=true

# Remove TEGRA_ROOT, no longer required and should never be used.

if [ -n "$TEGRA_ROOT" ]; then
    echo "WARNING: TEGRA_ROOT env variable is set to: $TEGRA_ROOT"
    echo "This variable has been superseded by TEGRA_TOP."
    echo "Removing TEGRA_ROOT from environment"
    unset TEGRA_ROOT
fi

if [ -f $HOME/lib/android/envsetup.sh ]; then
    echo including $HOME/lib/android/envsetup.sh
    .  $HOME/lib/android/envsetup.sh
fi

if [ -d $(gettop)/vendor/nvidia/proprietary_src ]; then
    export TEGRA_TOP=$(gettop)/vendor/nvidia/proprietary_src
elif [ -d $(gettop)/vendor/nvidia/tegra ]; then
    export TEGRA_TOP=$(gettop)/vendor/nvidia/tegra
else
    echo "WARNING: Unable to set TEGRA_TOP environment variable."
    echo "Valid TEGRA_TOP directories are:"
    echo "$(gettop)/vendor/nvidia/proprietary_src"
    echo "$(gettop)/vendor/nvidia/tegra"
    echo "At least one of them should exist."
    echo "Please make sure your Android source tree is setup correctly."
    # This script will be sourced, so use return instead of exit
    return 1
fi

if [ -f $TOP/vendor/pdk/mini_armv7a_neon/mini_armv7a_neon-userdebug/platform/platform.zip ]; then
    export PDK_FUSION_PLATFORM_ZIP=$TOP/vendor/pdk/mini_armv7a_neon/mini_armv7a_neon-userdebug/platform/platform.zip
fi

if [ `uname` == "Darwin" ]; then
    if [[ -n $FINK_ROOT && -z $GNU_COREUTILS ]]; then
        export GNU_COREUTILS=${FINK_ROOT}/lib/coreutils/bin
    elif [[ -n $MACPORTS_ROOT && -z $GNU_COREUTILS ]]; then
        export GNU_COREUTILS=${MACPORTS_ROOT}/local/libexec/gnubin
    elif [[ -n $GNU_COREUTILS ]]; then
        :
    else
        echo "Cannot find GNU coreutils. Please set either GNU_COREUTILS, FINK_ROOT or MACPORTS_ROOT."
    fi
fi

# Disabled in early development phase.
#if [ -f $TEGRA_TOP/tmake/scripts/envsetup.sh ]; then
#    _nvsrc=$(echo ${TEGRA_TOP}|colrm 1 `echo $TOP|wc -c`)
#    echo "including ${_nvsrc}/tmake/scripts/envsetup.sh"
#    . $TEGRA_TOP/tmake/scripts/envsetup.sh
#fi

# Temporary HACK to remove pieces of the PDK
if [ -n "$PDK_FUSION_PLATFORM_ZIP" ]; then
    zip -q -d $PDK_FUSION_PLATFORM_ZIP "system/vendor/*" >/dev/null 2>/dev/null || true
fi

# export Coverity executable if NV_KERNEL_COVERITY_ENABLED is set to 1.
if [[ ${NV_KERNEL_COVERITY_ENABLED} == 1 ]]; then
    if [[ -n "$P4ROOT" && -f  $P4ROOT/sw/mobile/tools/coverity/coverity_8.6.0/bin/cov-configure ]]; then
        export PATH=$PATH:$P4ROOT/sw/mobile/tools/coverity/coverity_8.6.0/bin
    else
        unset NV_KERNEL_COVERITY_ENABLED
    fi
fi

if [ -z "$BULLSEYE_ROOT" ]; then
    BULLSEYE_ROOT=$P4ROOT/sw/tools/Bullseye/linux/linux64/8.14.4
    export BULLSEYE_ROOT
fi

if [ -d $BULLSEYE_ROOT ]; then
    export PATH=$PATH:$BULLSEYE_ROOT/bin
fi

function _get_bullseye_pristine_target_covfile
{
    echo $ANDROID_PRODUCT_OUT/bullseye.cov
}

function _get_bullseye_target_covfile
{
    echo /data/bullseye.cov
}

function _get_bullseye_pristine_host_covfile
{
    echo $ANDROID_HOST_OUT/bullseye.cov
}

function _get_bullseye_host_covfile
{
    echo $ANDROID_HOST_OUT/bin/bullseye.cov
}

function _get_bullseye_analysis_dir
{
    echo $(gettop)/out/bullseye_analysis
}

function bullseye_help()
{
    echo "The bullseye_* commands are meant to gather code coverage data with the"
    echo "Bullseye tool."
    echo ""
    echo "Build commands:"
    echo "- bullseye_build_enable: Instruct the build system to instrument binaries"
    echo "- bullseye_build_disable: Stop instrumenting binaries"
    echo "- bullseye_build_reset: Reset Bullseye's build copy of the coverage data"
    echo ""
    echo "Target commands:"
    echo "- bullseye_target_init: Init or reset Bullseye coverage data file on target"
    echo "- bullseye_target_run: Run test on target and append to coverage data file"
    echo "- bullseye_target_analyze: Download coverage data file and open in Bullseye"
    echo "- bullseye_target_html: Download coverage data file and create HTML report"
    echo "                        (includes branch coverage as 'decision coverage')"
    echo ""
    echo "Host commands:"
    echo "- bullseye_host_init: Same as bullseye_target_init for host binaries"
    echo "- bullseye_host_run: Same as bullseye_host_run for host binaries"
    echo "- bullseye_host_analyze: Same as bullseye_host_analyze for host binaries"
    echo "- bullseye_host_html: Same as bullseye_host_html for host binaries"
    echo ""
    echo "It is recommended to start by performing a full build without coverage"
    echo "instrumentation, then incrementally rebuild the components of interest"
    echo "with instrumentation and run associated tests to gather coverage"
    echo "figures."
    echo ""
    echo "Note that Bullseye instrumented binaries will not be able to save"
    echo "coverage data by default, and will instead print an error message."
    echo "You can rely on this to perform dry runs, then call the 'bullseye_*_run'"
    echo "commands when ready to gather data."
    echo "There will also be benign error messages in case some instrumented"
    echo "components used by your test were built before a 'bullseye_build_reset'."
    echo "Coverage data for these components will not be gathered."
    echo ""
    echo "Example of coverage session:"
    echo "  mp dev nvidia-tests"
    echo "  bullseye_build_enable"
    echo "  cd <my_component> && mmp"
    echo "  adb sync && bullseye_target_init"
    echo "  bullseye_target_run <my_test_app>"
    echo "  bullseye_target_analyze"
    echo "  bullseye_build_disable"
}

function bullseye_build_enable()
{
    if [ -d $BULLSEYE_ROOT ]; then
        export BULLSEYE_COVERAGE_ENABLED=1
    else
        echo "Cannot find Bullseye directory $BULLSEYE_ROOT. Keeping Bullseye disabled."
        return
    fi
}

function bullseye_build_disable()
{
    unset BULLSEYE_COVERAGE_ENABLED
}

function bullseye_build_reset()
{
    rm -f $(_get_bullseye_pristine_target_covfile)
    find $ANDROID_PRODUCT_OUT -name bullseye.stamp -type f -delete
    rm -f $(_get_bullseye_pristine_host_covfile)
    find $ANDROID_HOST_OUT -name bullseye.stamp -type f -delete
}

function bullseye_target_init()
{
    local _pristine_cov=$(_get_bullseye_pristine_target_covfile)
    if [ ! -f $_pristine_cov ]; then
        echo "Pristine Bullseye coverage file $_pristine_cov not found. Have you built any target component with coverage enabled?"
        return
    fi
    adbserver
    adb push $_pristine_cov $(_get_bullseye_target_covfile)
    echo "Pushed pristine Bullseye coverage file. Make sure to also sync instrumented drivers to the device."
}

function bullseye_target_run()
{
    local _target_cov=$(_get_bullseye_target_covfile)
    adbserver
    if adb shell test ! -f $_target_cov; then
        echo "Bullseye coverage file $_target_cov not found on target. Have you run 'bullseye_target_init'?"
        return
    fi
    adb shell COVFILE=$_target_cov $@
}

function _bullseye_target_download()
{
    local _target_cov=$(_get_bullseye_target_covfile)
    local _analysis_dir=$(_get_bullseye_analysis_dir)
    adbserver
    if adb shell test ! -f $_target_cov; then
        echo "Bullseye coverage file $_target_cov not found on target. Have you run 'bullseye_target_init'?"
        return 1
    fi
    rm -rf $_analysis_dir
    mkdir -p $_analysis_dir
    adb pull $_target_cov $_analysis_dir/bullseye.cov
    echo "Coverage file saved at $_analysis_dir/bullseye.cov"
}

function bullseye_target_analyze()
{
    _bullseye_target_download
    if [ $? -ne 0 ]; then
        return
    fi
    COVSRCDIR=$(gettop) CoverageBrowser $(_get_bullseye_analysis_dir)/bullseye.cov
}

function bullseye_target_html()
{
    local _analysis_dir=$(_get_bullseye_analysis_dir)
    _bullseye_target_download
    if [ $? -ne 0 ]; then
        return
    fi
    covhtml --no-banner --decision --srcdir $(gettop) --file $_analysis_dir/bullseye.cov $_analysis_dir
    echo "Coverage analysis saved at $_analysis_dir/index.html"
    xdg-open $_analysis_dir/index.html
}

function bullseye_host_init()
{
    local _pristine_cov=$(_get_bullseye_pristine_host_covfile)
    if [ ! -f $_pristine_cov ]; then
        echo "Pristine Bullseye coverage file $_pristine_cov not found. Have you built any host component with coverage enabled?"
        return
    fi
    cp $_pristine_cov $(_get_bullseye_host_covfile)
    echo "Copied pristine Bullseye coverage file."
}

function bullseye_host_run()
{
    local _host_cov=$(_get_bullseye_host_covfile)
    if [ ! -f $_host_cov ]; then
        echo "Bullseye coverage file $_host_cov not found. Have you run 'bullseye_host_init'?"
        return 1
    fi
    COVFILE=$_host_cov $@
}

function _bullseye_host_download()
{
    local _host_cov=$(_get_bullseye_host_covfile)
    local _analysis_dir=$(_get_bullseye_analysis_dir)
    if [ ! -f $_host_cov ]; then
        echo "Bullseye coverage file $_host_cov not found. Have you run 'bullseye_host_init'?"
        return
    fi
    rm -rf $_analysis_dir
    mkdir -p $_analysis_dir
    cp $_host_cov $_analysis_dir/bullseye.cov
    echo "Coverage file saved at $_analysis_dir/bullseye.cov"
}

function bullseye_host_analyze()
{
    _bullseye_host_download
    if [ $? -ne 0 ]; then
        return
    fi
    COVSRCDIR=$(gettop) CoverageBrowser $(_get_bullseye_analysis_dir)/bullseye.cov
}

function bullseye_host_html()
{
    local _analysis_dir=$(_get_bullseye_analysis_dir)
    _bullseye_host_download
    if [ $? -ne 0 ]; then
        return
    fi
    covhtml --no-banner --decision --srcdir $(gettop) --file $_analysis_dir/bullseye.cov $_analysis_dir
    echo "Coverage analysis saved at $_analysis_dir/index.html"
    xdg-open $_analysis_dir/index.html
}
