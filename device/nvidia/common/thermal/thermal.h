/*
 * Copyright (c) 2016-2017, NVIDIA CORPORATION.  All rights reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#ifndef _TEGRA_THERMAL_H
#define _TEGRA_THERMAL_H

#define MAX_LENGTH         100

typedef struct thermal_desc_t {
    char *name;
    int type;
    char *sensor_label;          /* from thermal_zoneX/type */
    float throttling_threshold;
    float vr_throttling_threshold;
    float shutdown_threshold;
    char *threshold_label;
    char *throttling_threshold_path;
    char *vr_throttling_threshold_path;
    char *shutdown_threshold_path;
    float multiplier;                       /* Conversion factor to celsius */
    int cores;                              /* CPUs only: cores to report */
    char **core_names;
    int (*read_temperature)(const struct thermal_desc_t *, temperature_t *, int size);
    char *temperature_path;
} thermal_desc_t;

typedef struct cooling_desc_t {
    char *name;
    int type;
    char *cooling_path;
} cooling_desc_t;

int read_cluster_temperature(const thermal_desc_t *in, temperature_t *out, int size);
int read_temperature(const thermal_desc_t *in, temperature_t *out, int size);

#endif // _TEGRA_THERMAL_H
