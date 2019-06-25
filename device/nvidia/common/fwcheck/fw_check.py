#!/usr/bin/python

'''
Copyright (c) 2015-2018, NVIDIA CORPORATION.  All rights reserved.

NVIDIA CORPORATION and its licensors retain all intellectual property
and proprietary rights in and to this software, related documentation
and any modifications thereto.  Any use, reproduction, disclosure or
distribution of this software and related documentation without an express
license agreement from NVIDIA CORPORATION is strictly prohibited
'''


import xml.etree.ElementTree as ET
import sys
import subprocess as sp
import os
import time

# debug flag
debug = 0

# define return codes
PASS = 0
FW_NOT_APPROVED = 1
FW_NO_EXIST = 2
FUNCTION_NOT_FOUND = 3
NOT_DEFINED_IN_XML = 4

# supported foster SKUs
SKU_FOSTER_BASE = "Foster Base"
SKU_FOSTER_RPMB = "Foster Pro (RPMB)"
SKU_FOSTER_CPC = "Foster Pro (CPC)"
SKU_DARCY = "Darcy"

# define global variables
SKU_ON_DEVICE = ""
fw_xml_fn = "fw_version.xml"
fw_xml_loc = "/system/vendor/etc/"
max_length = 100
left_border = 1
right_border = 1

def print_info(tag, args):
    if debug:
        print "[%s] %s" % (tag, args)


def run_cmd(tag, cmd, strip=True):
    try:
        print_info(tag, "try execute: " + cmd)
        process = sp.Popen(cmd, shell=True, stdout=sp.PIPE, stderr=sp.PIPE, stdin=sp.PIPE)
        result = process.communicate()[0]
        if strip:
            result = result.strip(" \r\t\n")
    except Exception, exc:
        print("cmd exception caught. abort")
        sys.exit(1)
    return result

#
# return value:
#   return 1: if found usb hub
#   return 0: if not found
#
def find_usbHub(tag):
    idVendor = "05e3"
    idProduct_usb2 = "0610"
    idProduct_usb3 = "0616"
    found_hub_usb2 = False
    found_hub_usb3 = False
    usb_dev_path = "/sys/bus/usb/devices/"
    cmd = "adb shell ls " + usb_dev_path
    dir_list = run_cmd(tag, cmd).split('\n')

    for dir in dir_list:
        dir = dir.strip('\r')
        vendorPath = usb_dev_path + dir + "/idVendor"
        productPath = usb_dev_path + dir + "/idProduct"
        checkCmd = "adb shell ls " + usb_dev_path + dir + "/"
        vendorCmd = "adb shell cat " + vendorPath
        productCmd = "adb shell cat " + productPath

        usb_check_result = run_cmd(tag, checkCmd)
        if "idVendor" in usb_check_result and "idProduct" in usb_check_result:
            usb_idVendor = run_cmd(tag, vendorCmd)
            usb_idProduct = run_cmd(tag, productCmd)
        else:
            continue
        if usb_idVendor == idVendor and usb_idProduct == idProduct_usb2:
            found_hub_usb2 = True
        if usb_idVendor == idVendor and usb_idProduct == idProduct_usb3:
            found_hub_usb3 = True

    if found_hub_usb2 == False:
        print_info(tag, "Genesys usb 2.0 hub is NOT found")
    else:
        print_info(tag, "Genesys usb 2.0 hub is found")
    if found_hub_usb3 == False:
        print_info(tag, "Genesys usb 3.0 hub is NOT found")
    else:
        print_info(tag, "Genesys usb 3.0 hub is found")
    if found_hub_usb2 == False and found_hub_usb3 == False:
        return 0;
    return 1;

def check_fw_version(v_on_board, versions, exact_match = False):
    for v in versions:
        if exact_match:
            if v == v_on_board:
                return True
        else:
            if v in v_on_board:
                return True
    return False

class FWCheck():
    def __init__(self):
        self.name = "FWCheck"

    def check_emmc_fw(self, tag, versions, exception):
        cmd = "adb shell cat /sys/kernel/debug/mmc0/mmc0:0001/firmware_version"
        version_on_board = run_cmd(tag, cmd)
        if exception != None:
            exception = exception.text
            if exception in version_on_board:
                print_info(tag, "fw not detected on device")
                return (FW_NO_EXIST, None)
        if check_fw_version(version_on_board, versions, True):
            print_info(tag, "fw version match")
            return (PASS, version_on_board)
        else:
            print_info(tag, "fw mismatch, fw version on device: " + version_on_board)
            return (FW_NOT_APPROVED, version_on_board)

    def check_bt_fw(self, tag, versions, exception):
        cmd = "adb shell rm -f /sdcard/btsnoop_hci.log"
        result = run_cmd(tag, cmd)

        cmd = "adb shell setprop persist.bluetooth.btsnoopenable true"
        result = run_cmd(tag, cmd)

        cmd = "adb shell getprop persist.bluetooth.btsnoopenable"
        result = run_cmd(tag, cmd)
        if (cmp(result, "true") != 0):
            return (FW_NOT_APPROVED, "cannot enable bt snoop log")

        BT_STATE = 0;
        #Turn off BT
        cmd = "adb shell service call bluetooth_manager 8"
        result = run_cmd(tag, cmd)
        for retry in range(0, 10):
            time.sleep(1)
            cmd = "adb shell service call bluetooth_manager 5"
            result = run_cmd(tag, cmd)
            if (cmp(result, "Result: Parcel(00000000 00000000   '........')") == 0):
                BT_STATE = 1
                break

        if BT_STATE != 1:
            return (FW_NOT_APPROVED, "cannot turn off BT")

        #Turn on BT
        cmd = "adb shell service call bluetooth_manager 6"
        result = run_cmd(tag, cmd)
        for retry in range(0, 10):
            time.sleep(1)
            cmd = "adb shell service call bluetooth_manager 5"
            result = run_cmd(tag, cmd)
            if (cmp(result, "Result: Parcel(00000000 00000001   '........')") == 0):
                BT_STATE = 0
                break

        if BT_STATE != 0:
            return (FW_NOT_APPROVED, "cannot turn on BT")

        cmd = "adb pull /data/misc/bluetooth/logs/btsnoop_hci.log ."
        result = run_cmd(tag, cmd)
        if os.path.exists("btsnoop_hci.log") != True:
            return (FW_NOT_APPROVED, "cannot pull bt snoop log from device")

        cmd = 'hcidump -r btsnoop_hci.log | grep "BCM"'
        result = run_cmd(tag, cmd)
        btresult = result.split("'")[1]

        cmd = "rm -f ./btsnoop_hci.log"
        result = run_cmd(tag, cmd)

        if check_fw_version(btresult, versions):
            print_info(tag, "fw version match")
            return (PASS, btresult)
        else:
            print_info(tag, "fw version mismatch, fw on device: " + btresult)
            return (FW_NOT_APPROVED, btresult)

    def check_wifi_fw(self, tag, versions, exception):
        cmd = "adb shell dmesg | grep 'Firmware version ='"
        result = run_cmd(tag, cmd)
        result = result.split("version")[-1]
        if check_fw_version(result, versions):
            print_info(tag, "fw version match")
            return (PASS, result)
        else:
            print_info(tag, "fw version mismatch, fw on device: " + result)
            return (FW_NOT_APPROVED, result)

    def check_bcm_vendor(self, tag, versions, exception):
        cmd = "adb shell getprop ro.wifi.sdmmc"
        sdmmc_num = run_cmd(tag, cmd)

        if sdmmc_num == "":
            print_info(tag, "ro.wifi.sdmmc property not set, reading from sdmmc0")
            cmd = "adb shell ls /sys/bus/platform/devices/sdhci-tegra.0/mmc_host"
        else:
            print_info(tag, "ro.wifi.sdmmc property set, reading from sdmmc" + sdmmc_num)
            cmd = "adb shell ls /sys/bus/platform/devices/sdhci-tegra.%s/mmc_host" % sdmmc_num

        mmc = run_cmd(tag, cmd)
        cmd = "adb shell cat /sys/bus/sdio/devices/%s:0001:1/vendor" % mmc
        result = run_cmd(tag, cmd)
        if check_fw_version(result, versions):
            print_info(tag, "fw version match")
            return (PASS, result)
        else:
            print_info(tag, "fw version mismatch, fw on device: " + result)
            return (FW_NOT_APPROVED, result)

    def check_bcm_device(self, tag, versions, exception):
        cmd = "adb shell getprop ro.wifi.sdmmc"
        sdmmc_num = run_cmd(tag, cmd)

        if sdmmc_num == "":
            print_info(tag, "ro.wifi.sdmmc property not set, reading from sdmmc0")
            cmd = "adb shell ls /sys/bus/platform/devices/sdhci-tegra.0/mmc_host"
        else:
            print_info(tag, "ro.wifi.sdmmc property set, reading from sdmmc" + sdmmc_num)
            cmd = "adb shell ls /sys/bus/platform/devices/sdhci-tegra.%s/mmc_host" % sdmmc_num

        mmc = run_cmd(tag, cmd)
        cmd = "adb shell cat /sys/bus/sdio/devices/%s:0001:1/device" % mmc
        result = run_cmd(tag, cmd)
        if check_fw_version(result, versions):
            print_info(tag, "fw version match")
            return (PASS, result)
        else:
            print_info(tag, "fw version mismatch, fw on device: " + result)
            return (FW_NOT_APPROVED, result)

    def check_led_fw(self, tag, versions, exception):
        cmd = "adb shell cat /d/regmap/0-0009/registers | grep '03:'"
        result = run_cmd(tag, cmd)[3:]
        if len(result) == 0:
            return (FW_NO_EXIST, result)
        if check_fw_version(result, versions):
            print_info(tag, "fw version match")
            return (PASS, result)
        else:
            print_info(tag, "fw version mismatch, fw on device: " + result)
            return (FW_NOT_APPROVED, result)

    def check_cpc_fw(self, tag, versions, exception):
        cmd = "adb shell sil_load -v"
        result = run_cmd(tag, cmd)
        if exception != None:
            exception = exception.text
            if exception in result:
                print_info(tag, "fw not detected on device")
                return (FW_NO_EXIST, None)
        if check_fw_version(result, versions):
            print_info(tag, "fw version match")
            return (PASS, result)
        else:
            print_info(tag, "fw version mismatch, fw on device: " + result)
            return (FW_NOT_APPROVED, result)

    def check_sata_fw(self, tag, versions, exception):
        cmd = "adb shell cat /sys/bus/scsi/devices/target0:0:0/0:0:0:0/rev"
        result = run_cmd(tag, cmd)
        if exception != None:
            exception = exception.text
            if exception in result:
                print_info(tag, "fw not detected on device")
                return (FW_NO_EXIST, None)
        if check_fw_version(result, versions):
            print_info(tag, "fw version match")
            return (PASS, result)
        else:
            print_info(tag, "fw version mismatch, fw on device: " + result)
            return (FW_NOT_APPROVED, result)

    def check_usbhub_fw(self, tag, versions, exception):
        if find_usbHub(tag) == 0:
            print_info(tag, "usbhub not detected on device")
            return (FW_NO_EXIST, None)

        print_info(tag, "usbhub is detected on device")
        tool = "/vendor/bin/genesys_hub_update"
        ini_file = "/system/vendor/firmware/GL_SS_HUB_ISP_foster.ini"
        cmd = "adb shell " + tool + " -i " + ini_file + " -v"
        result = run_cmd(tag, cmd)
        if check_fw_version(result, versions):
            print_info(tag, "fw version match")
            return (PASS, result)
        else:
            print_info(tag, "fw version mismatch, fw on device: " + result)
            return (FW_NOT_APPROVED, result)

    def check_modem_fw(self, tag, versions, exception):
        cmd = "adb shell getprop gsm.version.baseband"
        result = run_cmd(tag, cmd)
        result = result.replace("-nala","",1)
        result = result.replace("-voice","",1)
        if check_fw_version(result, versions):
            print_info(tag, "fw version match")
            return (PASS, result)
        else:
            print_info(tag, "fw version mismatch, fw on device: " + result)
            return (FW_NOT_APPROVED, result)

    def check_mcu_fw(self, tag, versions, exception):
        matching_phrase_lsb = "03: "
        matching_phrase_msb = "04: "
        cmd = "adb shell cat /sys/devices/platform/7000c000.i2c/i2c-0/0-0009/misc/cy8c_panel_app/version"
        result = run_cmd(tag, cmd)
        if exception != None:
            exception = exception.text
            if exception in result:
                print_info(tag, "fw not detected on device")
                return (FW_NO_EXIST, None)
        if matching_phrase_msb in result:
            if matching_phrase_lsb in result:
                result_msb = result.split(matching_phrase_msb, 1)[1]
                result_lsb = result.split(matching_phrase_msb, 1)[0]
                result_lsb = result_lsb.strip(" \r\t\n")
                result_lsb = result_lsb.split(matching_phrase_lsb, 1)[1]
                result = result_msb + result_lsb
        if check_fw_version(result, versions):
            print_info(tag, "fw version match")
            return (PASS, result)
        else:
            print_info(tag, "fw version mismatch, fw on device: " + result)
            return (FW_NOT_APPROVED, result)

def run_setup():
    #
    # adb root first and pull xml file
    #
    adb_restart = "adb kill-server"
    result = run_cmd("setup", adb_restart)
    time.sleep(2)
    adb_root = "adb root"
    result = run_cmd("setup", adb_root)
    time.sleep(2)

    check_xml_cmd = "adb shell ls " + fw_xml_loc
    result = run_cmd("setup", check_xml_cmd)
    if fw_xml_fn not in result:
        print fw_xml_loc + fw_xml_fn + " doesn't exist on device. abort."
        return False

    pull_cmd = "adb pull " + fw_xml_loc + fw_xml_fn
    result = run_cmd("setup", pull_cmd)
    check_xml = "ls -la"
    result = run_cmd("setup", check_xml)
    if fw_xml_fn not in result:
        print "failed to pull %s. abort." % fw_xml_fn
        return False
    return True

def detect_sku():
    global SKU_ON_DEVICE
    sku_cmd = "adb shell cat /proc/device-tree/nvidia,dtsfilename"
    ret = run_cmd("sku", sku_cmd)
    if "foster-e-hdd-cpc" in ret:
        SKU_ON_DEVICE = SKU_FOSTER_CPC
    elif "foster-e-hdd" in ret:
        SKU_ON_DEVICE = SKU_FOSTER_RPMB
    elif "foster-e" in ret:
        SKU_ON_DEVICE = SKU_FOSTER_BASE
    elif "darcy" in ret:
        SKU_ON_DEVICE = SKU_DARCY
    else:
        return False

    detect_string = "Detected SKU: " + SKU_ON_DEVICE
    print "#" * max_length
    print "#" * left_border + " " * (max_length - left_border - right_border) + \
            "#" * right_border
    print "#" * left_border + \
            detect_string.center(max_length - left_border - right_border, " ") + \
            "#" * right_border
    print "#" * left_border + " " * (max_length - left_border - right_border) + \
            "#" * right_border
    print "#" * max_length
    print "\n"
    return True

def process_command(command, fw_name, versions, exception = None):
    cmd = "adb shell " + command
    result = run_cmd(fw_name, cmd)
    if exception != None:
        exception = exception.text
        if exception in result:
            print_info(fw_name, "fw not detected on device")
            return (FW_NO_EXIST, None)

    if check_fw_version(result, versions):
        print_info(fw_name, "fw version match")
        return (PASS, result)
    else:
        print_info(fw_name, "fw version mismatch, fw on device: " + result)
        return (FW_NOT_APPROVED, result)

def report_all_fw(device_fw_result, golden_fw_versions):
    abort = False
    index = 1

    for fw in device_fw_result:
        result = device_fw_result[fw]
        output = "%d : %s" % (index, fw)
        status = ""
        if result[0] == PASS:
            status = "[PASS]"
            print output.ljust(max_length - len(status), " ") + status
            print "\tOn device      : %s." % result[1]
            print "\tExpect version : %s." % " or ".join(golden_fw_versions[fw])
        elif result[0] == FW_NO_EXIST:
            status = "[WARNING]"
            print output.ljust(max_length - len(status), " ") + status
            print "\tOn device      : FW not found."
            print "\tExpect version : %s." % " or ".join(golden_fw_versions[fw])
        elif result[0] == FUNCTION_NOT_FOUND:
            abort = True
            status = "[ABORT]"
            print output.ljust(max_length - len(status), " ") + status
            print "\tFW check function not found in script."
        elif result[0] == NOT_DEFINED_IN_XML:
            abort = True
            status = "[ABORT]"
            print output.ljust(max_length - len(status), " ") + status
            print "\tFW check function not defined in xml."
        elif result[0] == FW_NOT_APPROVED:
            status = "[ERROR]"
            print output.ljust(max_length - len(status), " ") + status
            print "\tOn device      : %s." % result[1]
            print "\tExpect version : %s." % " or ".join(golden_fw_versions[fw])
        else:
            print output.ljust(max_length - len(status), " ") + status
            print "ERROR! SHOULD NEVER REACH HERE..."
        index += 1
        print ""

    if abort:
        sys.exit(1)
    else:
        return

def get_sku_required_fws(fw_required_skus):
    required_fws = []
    for fw in fw_required_skus:
        skus = fw_required_skus[fw]
        for each_sku in skus:
            if each_sku.text in SKU_ON_DEVICE:
                required_fws += [fw]
    return required_fws

def print_report(required_fws, device_fw_result):
    status = "PASS"

    error_fws = []
    print "\n"
    print "#" * max_length
    print "#" * left_border + " " * (max_length - left_border - right_border) + \
            "#" * right_border
    for fw in required_fws:
        if device_fw_result[fw][0] != PASS:
            status = "FAIL"
            error_fws += [fw]

    print "#" * left_border + \
            status.center(max_length - left_border - right_border, " ") + \
            "#" * right_border
    print "#" * left_border + " " * (max_length - left_border - right_border) + \
            "#" * right_border
    print "#" * max_length

    print "#" * left_border + " " * (max_length - left_border - right_border) + \
            "#" * right_border
    report = "%s requires %d FW checks. %d of %d Failed" \
            % (SKU_ON_DEVICE, len(required_fws), len(error_fws), len(required_fws))
    print "#" * left_border + \
            report.center(max_length - left_border - right_border, " ") + \
            "#" * right_border
    print "#" * left_border + " " * (max_length - left_border - right_border) + \
            "#" * right_border

    error_index = 1
    error_padding = 20
    for fw in error_fws:
        error_fw = "%d: %s" % (error_index, fw)
        print "#" * left_border + " " * error_padding + \
                error_fw.ljust(max_length - left_border - right_border - error_padding, " ") + \
                "#" * right_border
        error_index += 1
    print "#" * max_length

    return

def main():
    # set up environment
    if run_setup() == False:
        print "set up failed. abort."
        sys.exit(1)
    # detect sku of connected foster
    if detect_sku() == False:
        print "Detected unsupported SKU from dtsfilename. Please fix. abort"
        sys.exit(1)

    # initialize class
    fwcheck_class = FWCheck()

    # parse and check each fw listed in the xml file
    golden_fw_versions = {}
    device_fw_version = {}
    fw_required_skus = {}

    fw_tree_root = ET.ElementTree(file=fw_xml_fn).getroot()
    for fw in fw_tree_root:
        if fw.get('skip') == 'No':
            # parse fw name
            fw_name = None
            fw_name = fw.get('name')
            # parse function
            fw_func = fw.find('function')
            # parse command
            fw_command = fw.find('command')
            # parse exception (could be None)
            exception = fw.find('exception')

            # parse all approved fw versions
            fw_versions = []
            for each_version in fw.findall('version'):
                fw_versions += [each_version.text]
            # save all approved fw versions
            golden_fw_versions[fw_name] = fw_versions

            # parse sku
            fw_required_skus[fw_name] = fw.findall("required")

            print_info(fw_name, "Checking %s, expect version: %s" % (fw_name, " or ".join(fw_versions)))
            if fw_func != None:
                func_name = fw_func.text
                if callable(getattr(fwcheck_class, func_name)):
                    result = getattr(fwcheck_class, func_name)(fw_name, fw_versions, exception)
                else:
                    result = (FUNCTION_NOT_FOUND, None)
            elif fw_command != None:
                command_name = fw_command.text
                result = process_command(command_name, fw_name, fw_versions, exception)
            else:
                result = (NOT_DEFINED_IN_XML, None)
            device_fw_version[fw_name] = result

    # print status of all fw
    fw_errors = report_all_fw(device_fw_version, golden_fw_versions)

    # report PASS or FAIL based on mandatory fw checks per sku
    sku_required_fws = get_sku_required_fws(fw_required_skus)
    print_report(sku_required_fws, device_fw_version)

    sys.exit(0)

if __name__ == "__main__":
    main()
