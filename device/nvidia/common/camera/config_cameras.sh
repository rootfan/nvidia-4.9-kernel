#!/vendor/bin/sh

# Copyright (c) 2016-2018, NVIDIA CORPORATION.  All rights reserved.
# NVIDIA CORPORATION and its licensors retain all intellectual property
# and proprietary rights in and to this software, related documentation
# and any modifications thereto.  Any use, reproduction, disclosure or
# distribution of this software and related documentation without an express
# license agreement from NVIDIA CORPORATION is strictly prohibited.

# config_cameras.sh -- Configure camera features and media_profiles.xml
#                      depending on camera modules

# For more information, please see:
#    https://confluence.nvidia.com/display/CHI/Boot+Time+Camera+Configuration
#    https://wiki.nvidia.com/wmpwiki/index.php/Camera#Camera_Sensor_Board_Matrix
#    https://wiki.nvidia.com/wmpwiki/index.php/Camera/Android/Configuration

# Export PATH to use toolbox (log/ls/rm/ln/...) in vendor partition (/vendor/bin/)
# This avoids sepolicy violation when full_treble is enabled.
export PATH=/vendor/bin:$PATH

########################################################################
# Wrapper functions
########################################################################

set_camera_feature() {
    local feature="$1"
    local value="$2"

    # remove an existing feature file
    rm -f /data/camera_config/etc/permissions/android.hardware.${feature}.xml

    # create a symbolic link to /data/camera_config/etc/permissions folder
    if [[ "$value" == "true" ]]; then
        ln -s /odm/etc/camera_repo/android.hardware.${feature}.xml /data/camera_config/etc/permissions/android.hardware.${feature}.xml
    fi
}

# set camera feature only if the second parameter is 'true' or 'false'
set_feature() {
    if [[ "$2" == "true" || "$2" == "false" ]]; then
        set_camera_feature $1 $2
        if [[ "$2" == "true" ]]; then
            log_message "    [O] android.hardware.$1"
        else
            log_message "    [X] android.hardware.$1"
        fi
    fi
}

enable_autofocus () {
    set_feature "camera.autofocus" $1
}

enable_external () {
    set_feature "camera.external" $1
}

enable_flash_autofocus () {
    set_feature "camera.flash-autofocus" $1
}

enable_front () {
    set_feature "camera.front" $1
}

enable_full () {
    set_feature "camera.full" $1
}

enable_manual_postprocessing () {
    set_feature "camera.manual_postprocessing" $1
}

enable_manual_sensor () {
    set_feature "camera.manual_sensor" $1
}

enable_raw () {
    set_feature "camera.raw" $1
}

enable_camera () {
    set_feature "camera" $1
}

use_media_profiles() {
    local fileList="$1"
    local wordCount="$(echo \"$fileList\" | wc -w)"
    local firstFile="${fileList%% *}"
    local remainingFiles="${fileList#* }"

    if [[ ! -f "${firstFile}" ]]; then
        log_message "  [Error] ${firstFile} doesn't exist!"
        exit 1
    fi

    log_message "    /etc/media_profiles.xml would refer to ${firstFile}"

    # create symbolic link for the first file and rename it to media_profiles.xml
    # (FYI, another method to specify a path to media_profiles.xml is using 'setprop' at boot time:
    #  'setprop media.settings.xml [path to media_profile.xml]')
    ln -f -s $firstFile /data/camera_config/etc/media_profiles.xml

    if [[ "$wordCount" -gt 1 ]]; then
        # create symbolic links for remaining files
        for file in $remainingFiles; do
            ln -f -s $file /data/camera_config/etc/$(basename $file)
        done
    fi
}

# Log messages to both kernel and logcat
log_message() {
    echo "$1" > /dev/kmsg
    log -t "config_cameras.sh" -p i "$1"
}

# Get number of regular cameras
get_num_regular_cameras() {
  local num_usb_cameras=0
  for filename in $(ls /dev/usb/video4linux*); do
    if [[ -n "$(readlink -f $filename | grep "/dev/camera/video")" ]]; then
      ((num_usb_cameras++))  # increment the number of usb cameras
    fi
  done

  local num_regular_cameras=$(ls /dev/camera/video* | grep -c "/dev/camera/video")
  num_regular_cameras=$((num_regular_cameras - num_usb_cameras))
  echo $num_regular_cameras
}

########################################################################
# Module Definitions
# (the following information is used if it is not overrided by
#  the module definition file.)
########################################################################

AVAILABLE_CAM_MODULE_IDS=""

on_module_default() {
    enable_autofocus              true
    enable_external               false
    enable_flash_autofocus        false
    enable_front                  true
    enable_full                   true
    enable_manual_postprocessing  true
    enable_manual_sensor          true
    enable_raw                    true
    enable_camera                 true
    use_media_profiles            "/odm/etc/camera_repo/media_profiles.xml"
}


########################################################################
# Main function
########################################################################


if [[ "$1" == "setup" ]]; then
    local module_def_file="$(getprop tegra.camera.defpath)"
    local hardware_name="$(getprop ro.hardware)"
    local media_profiles_path="/etc/media_profiles.xml"
    local hardware_specific_media_profiles="false"

    # Nvidia modifies MediaProfiles.cpp in Android Framework code
    # so /etc/${ro.hardware}_media_profiles.xml is used if exists.
    if [[ -f "/etc/${hardware_name}_media_profiles.xml" ]]; then
        media_profiles_path="/etc/${hardware_name}_media_profiles.xml"
        hardware_specific_media_profiles="true"
        log_message "Hardware-specific media profile (${media_profiles_path}) would be used, ignoring /etc/media_profiles.xml"
    fi

    if [[ ! -f "${module_def_file}" ]]; then
        log_message "Camera module definition file ($module_def_file) doesn't exist!"
        log_message "  ${media_profiles_path} and /etc/permissions/android.hardware.camera*.xml would be used."
        exit 1
    fi

    log_message "Reading ${module_def_file} for Camera module definition."

    # Override AVAILABLE_CAM_MODULE_IDS and module definitions
    . ${module_def_file}

    MODULE_ID='default'
    AVAILABLE_CAM_MODULE_IDS="${AVAILABLE_CAM_MODULE_IDS}"

    # Check files in '/proc/device-tree/chosen/plugin-manager/ids/' folder and translate the output
    module_ids='#'$(ls -1 /proc/device-tree/chosen/plugin-manager/ids/ 2> /dev/null | tr '\n' '#' | xargs)
    for id in ${AVAILABLE_CAM_MODULE_IDS}; do
        # Check if substring "#${id}" is in module_ids, and set MODULE_ID to ${id}
        if [[ "$module_ids" != "${module_ids%\#${id}*}" ]]; then
            # Change id for some camera modules
            case "$id" in
                LPRD-002001)
                    MODULE_ID="imx185"
                    ;;
                LPRD-002002)
                    MODULE_ID="imx274"
                    ;;
                LPRD-dual-imx274-002)
                    MODULE_ID="dual_imx274"
                    ;;
                [0-9][0-9][0-9][0-9])
                    MODULE_ID="e${id}"
                    ;;
                *)
                    MODULE_ID="${id}"
                    ;;
            esac
            break
        fi
    done

    # Log camera module ID
    log_message "  Detected Camera module: ${MODULE_ID}"

    eval "on_module_${MODULE_ID}"
    exit 0
else
    echo "config_cameras.sh -- Configure camera features and media_profiles.xml"
    echo "                     depending on camera modules."
    echo "                     (used only by init.*.rc at boot time)"
    echo ""
    echo "Usage>"
    echo "  config_cameras.sh setup"
fi
