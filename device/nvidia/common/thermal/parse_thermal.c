/*
 * Copyright (c) 2017, NVIDIA CORPORATION.  All rights reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
#define LOG_TAG "ThermalHAL::parser"

#include <utils/Log.h>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>

#include <libxml/xmlreader.h>

#include "parse_thermal.h"
#include <hardware/hardware.h>
#include <hardware/thermal.h>
#include "thermal.h"

#define XML_PREFIX "/system/etc/thermalhal."
#define XML_SUFFIX ".xml"

thermal_desc_t * platform_data = NULL;
cooling_desc_t * cooling_data = NULL;
int * num_cpus_total = NULL;
int platform_data_count = 0;
int cooling_data_count = 0;

static int parse_cool_prop(xmlTextReaderPtr reader) {
    char * c = NULL;

    c = (char *) xmlTextReaderGetAttribute(reader, (const xmlChar *)"name");

    if (!cooling_data[cooling_data_count].name && c) {
        cooling_data[cooling_data_count].name = strdup(c);
        if (!cooling_data[cooling_data_count].name)
            return -ENOMEM;
    }

    c = (char *) xmlTextReaderGetAttribute(reader, (xmlChar *)"type");
    if (c != NULL) {
        if (!strcmp(c, "FAN_RPM"))
            cooling_data[cooling_data_count].type = FAN_RPM;
        else
            return -ENOENT;
    }

    c = (char *) xmlTextReaderGetAttribute(reader, (const xmlChar *)"cooling-path");
    if (!cooling_data[cooling_data_count].cooling_path && c) {
        cooling_data[cooling_data_count].cooling_path = strdup(c);
        if (!cooling_data[cooling_data_count].cooling_path)
            return -ENOMEM;
    }
    return 0;
}

static int parse_therm_prop(xmlTextReaderPtr reader) {
    char * c = NULL;

    c = (char *) xmlTextReaderGetAttribute(reader, (const xmlChar *)"name");
    if (!platform_data[platform_data_count].name && c) {
        platform_data[platform_data_count].name = strdup(c);
        if (!platform_data[platform_data_count].name)
            return -ENOMEM;
    }

    c = (char *) xmlTextReaderGetAttribute(reader, (const xmlChar *)"sensor-label");
    if (!platform_data[platform_data_count].sensor_label && c) {
        platform_data[platform_data_count].sensor_label = strdup(c);
        if (!platform_data[platform_data_count].sensor_label)
            return -ENOMEM;
    }

    c = (char *) xmlTextReaderGetAttribute(reader, (const xmlChar *)"threshold-label");
    if (!platform_data[platform_data_count].threshold_label && c) {
        platform_data[platform_data_count].threshold_label = strdup(c);
        if (!platform_data[platform_data_count].threshold_label)
            return -ENOMEM;
    }

    c = (char *)xmlTextReaderGetAttribute(reader, (const xmlChar *)"multiplier");
    if (c != NULL)
        platform_data[platform_data_count].multiplier = atof(c);

    c = (char *)xmlTextReaderGetAttribute(reader, (xmlChar *)"type");
    if (c != NULL) {
        if (!strcmp(c, "DEVICE_TEMPERATURE_CPU"))
            platform_data[platform_data_count].type = DEVICE_TEMPERATURE_CPU;
        else if (!strcmp(c, "DEVICE_TEMPERATURE_GPU"))
            platform_data[platform_data_count].type = DEVICE_TEMPERATURE_GPU;
        else if (!strcmp(c, "DEVICE_TEMPERATURE_BATTERY"))
            platform_data[platform_data_count].type  = DEVICE_TEMPERATURE_BATTERY;
        else if (!strcmp(c, "DEVICE_TEMPERATURE_SKIN"))
            platform_data[platform_data_count].type  = DEVICE_TEMPERATURE_SKIN;
    }

    c = (char *)xmlTextReaderGetAttribute(reader, (xmlChar *)"cores");
    if (c != NULL) {
        int i = 0;
        int x = atoi(c);
        if (x > 0) {
            platform_data[platform_data_count].cores = x;
            platform_data[platform_data_count].read_temperature = read_cluster_temperature;
        }

        platform_data[platform_data_count].core_names = (char **)malloc(x*sizeof(char*));
        for (i=0; i<x ;i++) {
            platform_data[platform_data_count].core_names[i] = \
                (char *)malloc(strlen(c)+strlen(platform_data[platform_data_count].name) + 1);
            sprintf(platform_data[platform_data_count].core_names[i], "%s%d",\
                         platform_data[platform_data_count].name, i);
        }
    }
    return 0;
}
/**
 * processNode:
 * @reader: the xmlReader
 * This calls parse_therm_prop and parse_cool_prop
 */
static int processNode(xmlTextReaderPtr reader) {
    const xmlChar *name;
    static int thermal_flag = 0;
    static int cooling_flag = 0;
    int ret = 0;

    name = xmlTextReaderConstName(reader);
    if (name == NULL)
        name = BAD_CAST "--";

    // This is text node. Not spported for thermalhal
    if (xmlTextReaderNodeType(reader) == XML_READER_TYPE_TEXT ||\
         xmlTextReaderNodeType(reader) == XML_READER_TYPE_SIGNIFICANT_WHITESPACE)
        goto out;

    if (xmlTextReaderNodeType(reader) == XML_READER_TYPE_ELEMENT &&\
         !strcmp((char *)name, "thermal_device")) {
        platform_data = (thermal_desc_t *)realloc(platform_data, \
                            sizeof(thermal_desc_t)*(platform_data_count+1));
        if (!platform_data) {
            ALOGE("Memory allocation failed");
            ret = -ENOMEM;
            goto out;
        }

        platform_data[platform_data_count].throttling_threshold = UNKNOWN_TEMPERATURE;
        platform_data[platform_data_count].vr_throttling_threshold = UNKNOWN_TEMPERATURE;
        platform_data[platform_data_count].shutdown_threshold = UNKNOWN_TEMPERATURE;
        platform_data[platform_data_count].type = DEVICE_TEMPERATURE_UNKNOWN;
        platform_data[platform_data_count].cores = 0;
        platform_data[platform_data_count].core_names = NULL;
        platform_data[platform_data_count].name = NULL;
        platform_data[platform_data_count].sensor_label = NULL;
        platform_data[platform_data_count].threshold_label = NULL;
        platform_data[platform_data_count].throttling_threshold_path = NULL;
        platform_data[platform_data_count].vr_throttling_threshold_path = NULL;
        platform_data[platform_data_count].shutdown_threshold_path = NULL;
        platform_data[platform_data_count].temperature_path = NULL;
        platform_data[platform_data_count].read_temperature = NULL;
        thermal_flag = 1;
    }
    else if (xmlTextReaderNodeType(reader) == XML_READER_TYPE_END_ELEMENT && \
            !strcmp((char *)name, "thermal_device")) {
        thermal_flag = 0;
        platform_data_count++;
    }
    else if (xmlTextReaderNodeType(reader) == XML_READER_TYPE_ELEMENT && \
            !strcmp( (char *)name, "cooling_device")) {

        cooling_data = (cooling_desc_t *)realloc(cooling_data, \
                        sizeof(cooling_desc_t)*(cooling_data_count+1));
        if (!cooling_data) {
            ALOGE("Memory allocation failed");
            ret = -ENOMEM;
            goto out;
        }
        cooling_data[cooling_data_count].cooling_path = NULL;
        cooling_data[cooling_data_count].name = NULL;
        cooling_flag = 1;
    }
    else if (xmlTextReaderNodeType(reader) == XML_READER_TYPE_END_ELEMENT && \
            !strcmp((char *)name, "cooling_device")) {
        cooling_flag = 0;
        cooling_data_count++;
    }
    else if (xmlTextReaderNodeType(reader) == XML_READER_TYPE_ELEMENT && \
            !strcmp((char *)name, "cpu_usages")) {
        char *c = (char *)xmlTextReaderGetAttribute(reader, (xmlChar *)"cpus");
        if (c != NULL) {
            num_cpus_total = (int *) malloc(sizeof(int));
            if (num_cpus_total)
                *num_cpus_total = atoi(c);
            else {
                ALOGE("Memory allocation failed");
                ret = -ENOMEM;
                goto out;
            }
        }
        else {
            ALOGE("Prop num_cpus_total missing");
            ret = -EINVAL;
            goto out;
        }
    }
    else if (thermal_flag && !strcmp((char *)name, "thermal-prop") && \
                xmlTextReaderNodeType(reader) == XML_READER_TYPE_ELEMENT)
        ret = parse_therm_prop(reader);
    else if (cooling_flag && !strcmp((char *)name, "cooling-prop") && \
                xmlTextReaderNodeType(reader) == XML_READER_TYPE_ELEMENT)
        ret = parse_cool_prop(reader);
out:
    return ret;
}

/**
 * streamFile:
 * @filename: the file name to parse
 */
static int streamFile(const char *filename) {
    xmlTextReaderPtr reader;
    int ret;
    reader = xmlReaderForFile(filename, NULL, 0);
    if (reader != NULL) {
        ret = xmlTextReaderRead(reader);
        while (ret == 1) {
            ret = processNode(reader);
            if (ret != 0) {
                xmlFreeTextReader(reader);
                return ret;
            }

            ret = xmlTextReaderRead(reader);
        }
        xmlFreeTextReader(reader);

        if (ret != 0) {
            ALOGE("%s : Failed to parse", filename);
            return -EINVAL;
        }
    }
    else {
        ALOGE("Unable to open : %s", filename);
        return -EBADF;
    }
    return 0;
}

int parse_thermal_config_xml(char *hw_name) {
    size_t len = strlen(XML_PREFIX) + strlen(XML_SUFFIX) + strlen (hw_name) + 1;
    char filename[len];
    int ret = 0;

    strcpy(filename, XML_PREFIX);
    strcat(filename, hw_name);
    strcat(filename, XML_SUFFIX);
     /*
      * this initialize the library and check potential ABI mismatches
      * between the version it was compiled for and the actual shared
      * library used.
      */
    LIBXML_TEST_VERSION

    if (platform_data == NULL && cooling_data == NULL && num_cpus_total == NULL) {
        ALOGI("Processing %s", filename);
        ret = streamFile(filename);
        if (ret) {
            ALOGE("ThermalHAL parsing failed %s", filename);
            return ret;
        }
        /*
         * Cleanup function for the XML library.
         */
        xmlCleanupParser();
        /*
         * this is to debug memory for regression tests
         */
        xmlMemoryDump();
    }

    return 0;
}