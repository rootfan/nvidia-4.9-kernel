#!/usr/bin/python
#
# Copyright (c) 2011 NVIDIA Corporation.  All rights reserved.
#
# NVIDIA Corporation and its licensors retain all intellectual property
# and proprietary rights in and to this software, related documentation
# and any modifications thereto.  Any use, reproduction, disclosure or
# distribution of this software and related documentation without an express
# license agreement from NVIDIA Corporation is strictly prohibited.
#

import common

def FullOTA_InstallBegin(info):
    partitions = ["/staging", "/bmps"]
    filenames = ["blob", "bmp.blob"]
    for i,filepath in enumerate(['RADIO/blob', 'RADIO/bmp.blob']):
        try:
            info.input_zip.getinfo(filepath)
        except KeyError:
            continue;
        else:
            # emit the script code to install this data on the device
            info.script.AppendExtra(
                'nv_ota_file_check("%s", "%s") ||\n'
                ' abort("Checking OTA file content fail.");' % (filenames[i], partitions[i]))

def FullOTA_InstallEnd(info):
    partitions = ["/staging", "/bmps"]
    filenames = ["blob", "bmp.blob"]
    for i,filepath in enumerate(['RADIO/blob', 'RADIO/bmp.blob']):
        try:
            info.input_zip.getinfo(filepath)
        except KeyError:
            continue;
        else:
            # copy the data into the package.
            data = info.input_zip.read(filepath)
            common.ZipWriteStr(info.output_zip, filenames[i], data)
            # emit the script code to install this data on the device
            info.script.AppendExtra(
                'nv_copy_blob_file("%s", "%s");' % (filenames[i], partitions[i]))

def FullOTA_MultiBlblob_InstallBegin(info):
    partitions = ["/staging", "/staging", "/bmps"]
    filenames = ["blob", "blob_unified", "bmp.blob"]
    for i,filepath in enumerate(['RADIO/blob', 'RADIO/blob_unified', 'RADIO/bmp.blob']):
        try:
            info.input_zip.getinfo(filepath)
        except KeyError:
            assert False, "Check OTA file KeyError exception on %s" % (filepath)
        else:
            # emit the script code to install this data on the device
            info.script.AppendExtra(
                'nv_ota_file_check("%s", "%s") ||\n'
                ' abort("Checking OTA file content fail.");' % (filenames[i], partitions[i]))
    info.script.AppendExtra(
            '(getprop("ro.support.unified.blblob") == "1" &&\n'
            ' ui_print("blob_unified will be used.")) ||\n'
            ' ui_print("blob will be used.");')

def FullOTA_MultiBlblob_InstallEnd(info):
    partitions = ["/staging", "/staging", "/bmps"]
    filenames = ["blob", "blob_unified", "bmp.blob"]
    for i,filepath in enumerate(['RADIO/blob', 'RADIO/blob_unified', 'RADIO/bmp.blob']):
        try:
            info.input_zip.getinfo(filepath)
        except KeyError:
            continue;
        else:
            # copy the data into the package.
            data = info.input_zip.read(filepath)
            common.ZipWriteStr(info.output_zip, filenames[i], data)
            # add script code to select blob at the end
            if partitions[i] == "/staging":
                continue;
            # emit the script code to install this data on the device
            info.script.AppendExtra(
                'nv_copy_blob_file("%s", "%s");' % (filenames[i], partitions[i]))
    # conditionally copy blob
    info.script.AppendExtra(
            '(getprop("ro.support.unified.blblob") == "1" &&\n'
            ' nv_copy_blob_file("blob_unified", "/staging")) ||\n'
            ' nv_copy_blob_file("blob", "/staging");')

def IncrementalOTA_InstallBegin(info):
    partitions = ["/staging", "/bmps"]
    filenames = ["blob", "bmp.blob"]
    for i,filepath in enumerate(['RADIO/blob', 'RADIO/bmp.blob']):
        try:
            info.target_zip.getinfo(filepath)
        except KeyError:
            continue;
        else:
            target_data = info.target_zip.read(filepath)
            try:
                info.source_zip.getinfo(filepath)
                source_data = info.source_zip.read(filepath)
                if source_data == target_data:
                    # data is unchanged from previous build; no
                    # need to check it
                    continue;
                else:
                    info.script.AppendExtra(
                        'nv_ota_file_check("%s", "%s") || \n'
                        ' abort("Checking OTA file content fail.");' % (filenames[i], partitions[i]))
            except KeyError:
                    info.script.AppendExtra(
                        'nv_ota_file_check("%s", "%s") || \n'
                        ' abort("Except: Checking OTA file content fail.");' % (filenames[i], partitions[i]))

def IncrementalOTA_InstallEnd(info):
    partitions = ["/staging", "/bmps"]
    filenames = ["blob", "bmp.blob"]
    for i,filepath in enumerate(['RADIO/blob', 'RADIO/bmp.blob']):
        try:
            info.target_zip.getinfo(filepath)
        except KeyError:
            continue;
        else:
            target_data = info.target_zip.read(filepath)
            try:
                info.source_zip.getinfo(filepath)
                # copy the data into the package.
                source_data = info.source_zip.read(filepath)
                if source_data == target_data:
                    # data is unchanged from previous build; no
                    # need to reprogram it
                    continue;
                else:
                    # include the new dat in the OTA package
                    common.ZipWriteStr(info.output_zip, filenames[i], target_data)
                    # emit the script code to install this data on the device
                    info.script.AppendExtra(
                        'nv_copy_blob_file("%s", "%s");' % (filenames[i], partitions[i]))
            except KeyError:
                # include the new data in the OTA package
                common.ZipWriteStr(info.output_zip, filenames[i], target_data)
                # emit the script code to install this data on the device
                info.script.AppendExtra(
                    'nv_copy_blob_file("%s", "%s");' % (filenames[i], partitions[i]))

def IncrementalOTA_MultiBlblob_InstallBegin(info, index):
    partitions = ["/staging", "/staging", "/bmps"]
    filenames = ["blob", "blob_unified", "bmp.blob"]
    # check index within range and points to BL blob
    if index < 0 or index >= len(partitions) or partitions[index] != "/staging":
        assert False, "Invalid partitions list index %d." % (index)
    for i,filepath in enumerate(['RADIO/blob', 'RADIO/blob_unified', 'RADIO/bmp.blob']):
        try:
            info.target_zip.getinfo(filepath)
        except KeyError:
            continue;
        else:
            target_data = info.target_zip.read(filepath)
            try:
                info.source_zip.getinfo(filepath)
                source_data = info.source_zip.read(filepath)
                if source_data == target_data:
                    # data is unchanged from previous build; no
                    # need to check it
                    continue;
                elif partitions[i] == "/staging" and i != index:
                    # as multi BL blobs are contained in ota zip pakcage, only
                    # check the bl blob matching provided index
                    continue;
                else:
                    info.script.AppendExtra(
                        'nv_ota_file_check("%s", "%s") || \n'
                        ' abort("Checking OTA file content fail.");' % (filenames[i], partitions[i]))
            except KeyError:
                if partitions[i] == "/staging" and i != index:
                    continue;
                else:
                    info.script.AppendExtra(
                        'nv_ota_file_check("%s", "%s") || \n'
                        ' abort("Except: Checking OTA file content fail.");' % (filenames[i], partitions[i]))

def IncrementalOTA_MultiBlblob_InstallEnd(info, index):
    partitions = ["/staging", "/staging", "/bmps"]
    filenames = ["blob", "blob_unified", "bmp.blob"]
    for i,filepath in enumerate(['RADIO/blob', 'RADIO/blob_unified', 'RADIO/bmp.blob']):
        try:
            info.target_zip.getinfo(filepath)
        except KeyError:
            continue;
        else:
            target_data = info.target_zip.read(filepath)
            try:
                info.source_zip.getinfo(filepath)
                # copy the data into the package.
                source_data = info.source_zip.read(filepath)
                if source_data == target_data:
                    # data is unchanged from previous build; no
                    # need to reprogram it
                    continue;
                elif partitions[i] == "/staging" and i != index:
                    # as multi BL blobs are contained in ota zip pakcage, only copy
                    # the bl blob matching provided index to corresponding partition
                    continue;
                else:
                    # include the new dat in the OTA package
                    common.ZipWriteStr(info.output_zip, filenames[i], target_data)
                    # emit the script code to install this data on the device
                    info.script.AppendExtra(
                        'nv_copy_blob_file("%s", "%s");' % (filenames[i], partitions[i]))
            except KeyError:
                if partitions[i] == "/staging" and i != index:
                    # as multi BL blobs are contained in ota zip pakcage, only copy
                    # the bl blob matching provided index to corresponding partition
                    continue;
                # include the new data in the OTA package
                common.ZipWriteStr(info.output_zip, filenames[i], target_data)
                # emit the script code to install this data on the device
                info.script.AppendExtra(
                    'nv_copy_blob_file("%s", "%s");' % (filenames[i], partitions[i]))

def AbOTA_InstallEnd(info):
    filenames = ["bl_update_payload", "bmp.blob"]
    for i,filepath in enumerate(['RADIO/bl_update_payload', 'RADIO/bmp.blob']):
        try:
            info.input_zip.getinfo(filepath)
        except KeyError:
            continue;
        else:
            # copy the data into the package.
            data = info.input_zip.read(filepath)
            common.ZipWriteStr(info.output_zip, filenames[i], data)
