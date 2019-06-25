/*
 * Copyright (C) 2016 The Android Open Source Project
 * Copyright (c) 2016-2017, NVIDIA CORPORATION.  All rights reserved.
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

#include <ctype.h>
#include <dirent.h>
#include <errno.h>
#include <inttypes.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>


#define LOG_TAG "ThermalHAL"
#include <utils/Log.h>

#include <hardware/hardware.h>
#include <hardware/thermal.h>
#include <sys/system_properties.h>

#include "thermal.h"
#include "parse_thermal.h"

#define CPU_LABEL               "CPU"
#define CPU_USAGE_FILE          "/proc/stat"
#define THERMAL_ROOT_DIR        "/sys/class/thermal"
#define TEMPERATURE_FILE_FORMAT "/sys/class/thermal/thermal_zone%d/temp"
#define THERMAL_DIR             "thermal_zone"
#define CPU_ONLINE_FILE_FORMAT  "/sys/devices/system/cpu/cpu%d/online"

#define RPM_FAN_FILE            "/sys/kernel/debug/tegra_fan/cur_rpm"

#define TRIP_POINT              "trip_point"
#define THROTTLING_THRESHOLD    "passive"
#define VR_THROTTLING_THRESHOLD "passive"
#define SHUTDOWN_THRESHOLD      "critical"

#define HARDWARE_TYPE_PROP      "ro.hardware"

extern thermal_desc_t *platform_data;
extern cooling_desc_t *cooling_data;
extern int platform_data_count;
extern int cooling_data_count;

extern int *num_cpus_total;



static int update_threshold_path(char **path, char *type_cmp, char *type, char *file_name)
{
    if (!*path && !strcmp(type_cmp, type)) {
        if (!(*path = malloc(strlen(file_name) + 1)))
            return -ENOMEM;

        strcpy(*path, file_name);
    }
    return 0;
}

static int update_threshold_paths(int cnt, char *trip_point_type, char *file_name)
{
    int ret;

    if ((ret = update_threshold_path(&platform_data[cnt].throttling_threshold_path,
                        THROTTLING_THRESHOLD, trip_point_type, file_name)) < 0)
        return ret;

    if ((ret = update_threshold_path(&platform_data[cnt].vr_throttling_threshold_path,
                        VR_THROTTLING_THRESHOLD, trip_point_type, file_name)) < 0)
        return ret;

    if ((ret = update_threshold_path(&platform_data[cnt].shutdown_threshold_path,
                        SHUTDOWN_THRESHOLD, trip_point_type, file_name)) < 0)
        return ret;

    return 0;
}

static int search_threshold_paths(DIR *sub_dir, char *dir_name, int cnt)
{
    FILE *file;
    struct dirent *sub_de;
    char file_name[MAX_LENGTH];
    char trip_point_type[MAX_LENGTH];
    int ret;

    while ((sub_de = readdir(sub_dir)) != NULL) {
        if (strstr(sub_de->d_name, TRIP_POINT) && strstr(sub_de->d_name, "type")) {

            snprintf(file_name, MAX_LENGTH, "%s/%s", dir_name, sub_de->d_name);
            file = fopen(file_name, "r");
            if (file == NULL)
                continue;

            if (1 != fscanf(file, "%s", (char *)&trip_point_type)) {
                fclose(file);
                continue;
            }
            fclose(file);

            snprintf(file_name, MAX_LENGTH, "%s/%.*stemp",
                    dir_name, (int)(strlen(sub_de->d_name) - strlen("type")), sub_de->d_name);

            if ((ret = update_threshold_paths(cnt, trip_point_type, file_name)) < 0)
                return ret;

        }
    }

    return 0;
}

static int get_threshold_paths(char *current_label, struct dirent *de, int cnt)
{
    DIR *sub_dir;
    FILE *file;
    char dir_name[MAX_LENGTH];
    char threshold_label[MAX_LENGTH];
    int ret = 0;

    if (platform_data[cnt].threshold_label)
        snprintf(threshold_label, MAX_LENGTH, "%s", platform_data[cnt].threshold_label);
    else
        snprintf(threshold_label, MAX_LENGTH, "%s", platform_data[cnt].sensor_label);

    if (!strcmp(threshold_label, current_label)) {
        snprintf(dir_name, MAX_LENGTH, "%s/%s", THERMAL_ROOT_DIR, de->d_name);
        sub_dir = opendir(dir_name);
        if (sub_dir == NULL)
            return ret;

        ret = search_threshold_paths(sub_dir, dir_name, cnt);

        closedir(sub_dir);
    }
    return ret;
}

static int get_temperature_path(char *current_label, struct dirent *de, int cnt)
{
    char file_name[MAX_LENGTH];

    if (!strcmp(platform_data[cnt].sensor_label, current_label)) {
        snprintf(file_name, MAX_LENGTH, "%s/%s/temp", THERMAL_ROOT_DIR, de->d_name);

        platform_data[cnt].temperature_path = malloc(strlen(file_name) + 1);
        if (!platform_data[cnt].temperature_path)
            return -ENOMEM;

        strcpy(platform_data[cnt].temperature_path, file_name);
    }
    return 0;
}

static int get_paths()
{
    DIR *dir;
    struct dirent *de;
    char file_name[MAX_LENGTH];
    char current_label[MAX_LENGTH];
    FILE *file;
    int ret;

    for (int i = 0; i < platform_data_count; i++) {
        if (!platform_data[i].temperature_path ||
            !platform_data[i].throttling_threshold_path ||
            !platform_data[i].vr_throttling_threshold_path ||
            !platform_data[i].shutdown_threshold_path) {
            break;
        } else {
            return 0;
        }
    }

    dir = opendir(THERMAL_ROOT_DIR);

    while ((de = readdir(dir)) != NULL) {
        if (!strncmp(de->d_name, THERMAL_DIR, strlen(THERMAL_DIR))) {
            snprintf(file_name, MAX_LENGTH, "%s/%s/type", THERMAL_ROOT_DIR, de->d_name);
        }
        file = fopen(file_name, "r");

        if (file == NULL)
            continue;

        if (1 != fscanf(file, "%s", (char *)&current_label)) {
            fclose(file);
            continue;
        }
        fclose(file);

        for (int i = 0; i < platform_data_count; i++) {
            if (!platform_data[i].temperature_path) {
                if ((ret = get_temperature_path(current_label, de, i)) < 0)
                    return ret;
            }

            if (!platform_data[i].throttling_threshold_path ||
                !platform_data[i].vr_throttling_threshold_path ||
                !platform_data[i].shutdown_threshold_path) {
                if ((ret = get_threshold_paths(current_label, de, i)) < 0)
                    return ret;
            }
        }

    }
    closedir(dir);
    return 0;
}

static int read_temp_file(char *path, int size, float *temp)
{
    int ret;
    FILE *fp;

    if (size < 1)
        return -ENOMEM;

    if (path)
        fp = fopen(path, "r");
    else
        return -ENOENT;

    if (fp == NULL)
        return -ENOENT;

    ret = fscanf(fp, "%f", temp);
    fclose(fp);
    return ret;
}

int read_temperature(const thermal_desc_t *in, temperature_t *out, int size)
{
    float temp, throttling, vr_throttling, shutdown;

    if (read_temp_file(in->temperature_path, size, &temp) != 1)
        return -ENOENT;

    if (read_temp_file(in->throttling_threshold_path, size, &throttling) != 1)
        return -ENOENT;

    if (read_temp_file(in->vr_throttling_threshold_path, size, &vr_throttling) != 1)
        return -ENOENT;

    if (read_temp_file(in->shutdown_threshold_path, size, &shutdown) != 1)
        return -ENOENT;

    (*out) = (temperature_t) {
        .type = in->type,
        .name = in->name,
        .current_value = temp * in->multiplier,
        .throttling_threshold = throttling * in->multiplier,
        .shutdown_threshold = shutdown * in->multiplier,
        .vr_throttling_threshold = vr_throttling * in->multiplier
    };

    // Added "1" temperature to list
    return 1;
}

int read_cluster_temperature(const thermal_desc_t *in, temperature_t *out, int size)
{
    int ret;

    if (size < in->cores)
        return -ENOMEM;

    if ((ret = read_temperature(in, out, size)) < 0)
        return ret;

    out->name = in->core_names[0];

    for (int i = 1; i < in->cores; i++) {
        temperature_t *next = &out[i];
        *next = *out;
        next->name = in->core_names[i];
    }

    return in->cores;
}

static ssize_t get_temperatures(thermal_module_t *module, temperature_t *list, size_t size) {
    size_t idx = 0;
    int ret = 0;
    char hw_name[PROP_VALUE_MAX];

    if (__system_property_get(HARDWARE_TYPE_PROP, hw_name)) {
        ret = parse_thermal_config_xml(hw_name);
        if (ret) {
            ALOGE("Parsing failed");
            return -EINVAL;
        }
    }
    else{
        ALOGE("Could not read property %s", HARDWARE_TYPE_PROP);
        return -ENOENT;
    }

    if (list == NULL) {
        for (int i = 0; i < platform_data_count; i++)
            ret += platform_data[i].cores ? platform_data[i].cores : 1;
        return ret;
    }

    if (size == 0)
        return -ENOMEM;

    ret = get_paths();
    if (ret < 0)
        goto out;

    for (int i = 0; i < platform_data_count; i++) {
        if (platform_data[i].read_temperature)
            ret = platform_data[i].read_temperature(&platform_data[i], &list[idx], size - idx);
        else
            ret = read_temperature(&platform_data[i], &list[idx], size - idx);

        if (ret < 0)
            goto out;
        else
            idx += ret;
    }

    /* Success.  Return number of entries */
    ret = idx;
    return ret;

out:
    for (int i = 0; i < platform_data_count; i++) {
        if (platform_data[i].temperature_path) {
            free(platform_data[i].temperature_path);
            platform_data[i].temperature_path = NULL;
        }
    }

    return ret;
}

static ssize_t get_cpu_usages(thermal_module_t *module, cpu_usage_t *list) {
    int vals, cpu_num, online;
    ssize_t read;
    uint64_t user, nice, system, idle, active, total;
    char *line = NULL;
    size_t len = 0;
    size_t size = 0;
    char file_name[MAX_LENGTH];
    FILE *cpu_file;
    FILE *file;
    int ret = 0;

    char hw_name[PROP_VALUE_MAX];

    if (__system_property_get(HARDWARE_TYPE_PROP, hw_name)) {
        ret = parse_thermal_config_xml(hw_name);
        if (ret) {
            ALOGE("Parsing failed");
            return -EINVAL;
        }
    }
    else{
        ALOGE("Could not read property %s", HARDWARE_TYPE_PROP);
        return -ENOENT;
    }

    if (list == NULL) {
        return *num_cpus_total;
    }

    file = fopen(CPU_USAGE_FILE, "r");
    if (file == NULL) {
        ALOGE("%s: failed to open: %s", __func__, strerror(errno));
        return -errno;
    }

    while ((read = getline(&line, &len, file)) != -1) {
        // Skip non "cpu[0-9]" lines.
        if (strnlen(line, read) < 4 || strncmp(line, "cpu", 3) != 0 || !isdigit(line[3])) {
            free(line);
            line = NULL;
            len = 0;
            continue;
        }
        vals = sscanf(line, "cpu%d %" SCNu64 " %" SCNu64 " %" SCNu64 " %" SCNu64, &cpu_num, &user,
                &nice, &system, &idle);

        free(line);
        line = NULL;
        len = 0;

        if (vals != 5) {
            ALOGE("%s: failed to read CPU information from file: %s", __func__, strerror(errno));
            fclose(file);
            return errno ? -errno : -EIO;
        }

        active = user + nice + system;
        total = active + idle;

        // Read online CPU information.
        snprintf(file_name, MAX_LENGTH, CPU_ONLINE_FILE_FORMAT, cpu_num);
        cpu_file = fopen(file_name, "r");
        online = 0;
        if (cpu_file == NULL) {
            ALOGE("%s: failed to open file: %s (%s)", __func__, file_name, strerror(errno));
            // /sys/devices/system/cpu/cpu0/online is missing on some systems, because cpu0 can't
            // be offline.
            online = cpu_num == 0;
        } else if (1 != fscanf(cpu_file, "%d", &online)) {
            ALOGE("%s: failed to read CPU online information from file: %s (%s)", __func__,
                    file_name, strerror(errno));
            fclose(file);
            fclose(cpu_file);
            return errno ? -errno : -EIO;
        } else
            fclose(cpu_file);

        if (list != NULL) {
            list[size] = (cpu_usage_t) {
                .name = CPU_LABEL,
                .active = active,
                .total = total,
                .is_online = online
            };
        }

        size++;
    }

    fclose(file);
    return size;
}

static ssize_t get_cooling_devices(thermal_module_t *module, cooling_device_t *list, size_t size) {
    struct stat buffer;
    FILE *file;
    float rpm;
    int ret = 0, count = 0;
    char cooling_file[MAX_LENGTH];
    char hw_name[PROP_VALUE_MAX];

    if (__system_property_get(HARDWARE_TYPE_PROP, hw_name)){
        ret = parse_thermal_config_xml(hw_name);
        if (ret) {
            ALOGE("Parsing failed");
            return -EINVAL;
        }
    }
    else{
        ALOGE("Could not read property %s", HARDWARE_TYPE_PROP);
        return -ENOENT;
    }

    if (list == NULL) {
        for (int i=0;i < cooling_data_count;i++) {
            snprintf(cooling_file, MAX_LENGTH, "%s",
                (cooling_data[i].cooling_path ? cooling_data[i].cooling_path : RPM_FAN_FILE));
            count += (stat(cooling_file, &buffer) == 0) ? 1 : 0;
        }
        return count;
    }

    if (size <= 0)
        return -ENOMEM;

    for (count=0; count < (int)size; count++) {
        snprintf(cooling_file, MAX_LENGTH, "%s",
                (cooling_data[count].cooling_path ? cooling_data[count].cooling_path : RPM_FAN_FILE) );


        file = fopen(cooling_file, "r");

        if (file == NULL) {
            ALOGE("%s: failed to open: %s", __func__, strerror(errno));
            return -errno;
        }

        ret = fscanf(file, "%f", &rpm);
        fclose(file);

        if (ret != 1)
            return -ENOENT;

        list[count] = (cooling_device_t) {
            .type = cooling_data[count].type,
            .name = cooling_data[count].name,
            .current_value = rpm,
        };
    }

    return count;
}

static struct hw_module_methods_t thermal_module_methods = {
    .open = NULL,
};

thermal_module_t HAL_MODULE_INFO_SYM = {
    .common = {
        .tag = HARDWARE_MODULE_TAG,
        .module_api_version = THERMAL_HARDWARE_MODULE_API_VERSION_0_1,
        .hal_api_version = HARDWARE_HAL_API_VERSION,
        .id = THERMAL_HARDWARE_MODULE_ID,
        .name = "Tegra Thermal HAL",
        .author = "The Android Open Source Project",
        .methods = &thermal_module_methods,
    },

    .getTemperatures = get_temperatures,
    .getCpuUsages = get_cpu_usages,
    .getCoolingDevices = get_cooling_devices,
};
