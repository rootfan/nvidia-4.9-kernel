/*
 * Copyright (c) 2016, NVIDIA CORPORATION.  All rights reserved.
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

#include <hardware/hardware.h>
#include <hardware/thermal.h>

#include "thermal.h"

const char *CPU_LABEL[] = {"CPU0", "CPU1", "CPU2", "CPU3"};

/*
 * This list should fully describe sensors on the platform that provide the
 * temperatures for CPU, GPU, skin, and battery.  Use UNKNOWN_TEMPERATURE for
 * undefined/unused thresholds.
 */
thermal_desc_t platform_data[] = {
    {
        .name = "CPU",
        .type = DEVICE_TEMPERATURE_CPU,
        .sensor_label = "CPU-therm",
        .multiplier = 0.001,
        .cores = 4,
        .core_names = CPU_LABEL,
        .read_temperature = read_cluster_temperature,
    },
    {
        .name = "GPU",
        .type = DEVICE_TEMPERATURE_GPU,
        .sensor_label = "GPU-therm",
        .multiplier = 0.001,
    },
};

cooling_desc_t cooling_data = {
    .name = "FAN",
    .type = FAN_RPM,
    .cooling_path = "/sys/kernel/debug/tegra_fan/rpm_measured",
};

int platform_data_count = sizeof(platform_data)/sizeof(platform_data[0]);

int num_cpus_total = 4;
