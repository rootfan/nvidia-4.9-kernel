/*
 * Copyright (C) 2012 The Android Open Source Project
 * Copyright (c) 2012-2017, NVIDIA CORPORATION.  All rights reserved.
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

#ifndef COMMON_POWER_HAL_H
#define COMMON_POWER_HAL_H

#include <hardware/hardware.h>
#include <hardware/power.h>

#include "powerhal_utils.h"
#include "timeoutpoker.h"
#include <semaphore.h>

#include <vector>

#define MAX_CHARS 32

#define POWER_CAP_PROP "persist.sys.NV_PBC_PWR_LIMIT"

//PMQOS control entry
#define PMQOS_CONSTRAINT_CPU_FREQ       "/dev/constraint_cpu_freq"
#define PMQOS_CONSTRAINT_GPU_FREQ       "/dev/constraint_gpu_freq"
#define PMQOS_CONSTRAINT_ONLINE_CPUS    "/dev/constraint_online_cpus"

//Default value to align with kernel pm qos
#define PM_QOS_DEFAULT_VALUE		-1

#define PRISM_CONTROL_PROP              "persist.sys.didim.enable"

#define PM_QOS_BOOST_PRIORITY 35
#define PM_QOS_APP_PROFILE_PRIORITY  40

#define HARDWARE_TYPE_PROP "ro.hardware"

#define NV_POWER_HINT_START POWER_HINT_VSYNC

#ifdef PLATFORM_IS_AFTER_N
/*
 * Power hint identifiers passed to (*powerHint)
 */
typedef enum {
    NV_POWER_HINT_VSYNC                 = POWER_HINT_VSYNC,
    NV_POWER_HINT_INTERACTION           = POWER_HINT_INTERACTION,
    /* DO NOT USE POWER_HINT_VIDEO_ENCODE/_DECODE!  They will be removed in
     * KLP.
     */
    NV_POWER_HINT_VIDEO_ENCODE          = POWER_HINT_VIDEO_ENCODE,
    NV_POWER_HINT_VIDEO_DECODE          = POWER_HINT_VIDEO_DECODE,
    NV_POWER_HINT_LOW_POWER             = POWER_HINT_LOW_POWER,
    NV_POWER_HINT_SUSTAINED_PERFORMANCE = POWER_HINT_SUSTAINED_PERFORMANCE,
    NV_POWER_HINT_VR_MODE               = POWER_HINT_VR_MODE,
    NV_POWER_HINT_LAUNCH                = POWER_HINT_LAUNCH,

    /* NVIDIA added hints start from here */
    POWER_HINT_APP_PROFILE           = 0x00000009,
    POWER_HINT_APP_LAUNCH            = 0x0000000A,
    POWER_HINT_SHIELD_STREAMING      = 0x0000000B,
    POWER_HINT_HIGH_RES_VIDEO        = 0x0000000C,
    POWER_HINT_POWER_MODE            = 0x0000000D,
    POWER_HINT_MIRACAST              = 0x0000000E,
    POWER_HINT_DISPLAY_ROTATION      = 0x0000000F,
    POWER_HINT_CAMERA                = 0x00000010,
    POWER_HINT_MULTITHREAD_BOOST     = 0x00000011,
    POWER_HINT_AUDIO_SPEAKER         = 0x00000012,
    POWER_HINT_AUDIO_OTHER           = 0X00000013,
    POWER_HINT_AUDIO_LOW_LATENCY     = 0x00000014,
    POWER_HINT_CANCEL_PHS_HINT       = 0x00000015,
    POWER_HINT_FRAMEWORKS_UI         = 0x00000016,

    POWER_HINT_COUNT
} nv_power_hint_t;

/*
 * App profile knobs, passed as data with POWER_HINT_APP_PROFILE hint
 */

typedef enum {
    APP_PROFILE_CPU_SCALING_MIN_FREQ,
    APP_PROFILE_CPU_CORE_BIAS,
    APP_PROFILE_CPU_MAX_NORMAL_FREQ_IN_PERCENTAGE,
    APP_PROFILE_CPU_MAX_CORE,
    APP_PROFILE_GPU_CBUS_CAP_LEVEL,
    APP_PROFILE_GPU_SCALING,
    APP_PROFILE_EDP_MODE,
    APP_PROFILE_PBC_POWER,
    APP_PROFILE_FAN_CAP,
    APP_PROFILE_VOLT_TEMP_MODE,
    APP_PROFILE_PRISM_CONTROL_ENABLE,
    APP_PROFILE_CPU_MIN_CORE,
    APP_PROFILE_COUNT,
} app_profile_knob;

/*
 * Camera power hint enum, passed as data with POWER_HINT_CAMERA hint
 */

typedef enum {
    CAMERA_HINT_STILL_PREVIEW_POWER,
    CAMERA_HINT_VIDEO_PREVIEW_POWER,
    CAMERA_HINT_VIDEO_RECORD_POWER,
    CAMERA_HINT_PERF,
    CAMERA_HINT_FPS,
    CAMERA_HINT_RESET,
    CAMERA_HINT_COUNT,
    CAMERA_HINT_HIGH_FPS_VIDEO_RECORD_POWER,
} camera_hint_t;

/*
 * NvCPL Power Mode power hint enum, passed as data with POWER_HINT_POWER_MODE
 * hint
 */
typedef enum {
    NVCPL_HINT_MAX_PERF,
    NVCPL_HINT_OPT_PERF,
    NVCPL_HINT_BAT_SAVE,
    NVCPL_HINT_USR_CUST,
    NVCPL_HINT_COUNT,
} nvcpl_hint_t;
#endif

struct input_dev_map {
    int dev_id;
    const char* dev_name;
};

typedef struct interactive_data {
    const char *hispeed_freq;
    const char *target_loads;
    const char *above_hispeed_delay;
    const char *timer_rate;
    const char *boost_factor;
    const char *min_sample_time;
    const char *go_hispeed_load;
} interactive_data_t;

typedef struct power_hint_data {
    int min;
    int max;
    int time_ms;
} power_hint_data_t;

typedef struct cpu_cluster_data {
    const char *pmqos_constraint_path;
    const char *available_freqs_path;
    int *available_frequencies;
    int num_available_frequencies;
    int fd_app_min_freq;
    int fd_app_max_freq;
    int fd_vsync_min_freq;

    power_hint_data_t hints[POWER_HINT_COUNT];
} cpu_cluster_data_t;

struct powerhal_info {
    TimeoutPoker* mTimeoutPoker;

    std::vector<cpu_cluster_data_t> cpu_clusters;

    bool ftrace_enable;
    bool no_cpufreq_interactive;
    bool no_sclk_boost;

    /* Holds input devices */
    std::vector<struct input_dev_map> input_devs;

    /* Time last hint was sent - in usec */
    uint64_t hint_time[POWER_HINT_COUNT];
    uint64_t hint_interval[POWER_HINT_COUNT];

    power_hint_data_t gpu_freq_hints[POWER_HINT_COUNT];
    power_hint_data_t emc_freq_hints[POWER_HINT_COUNT];
    power_hint_data_t online_cpu_hints[POWER_HINT_COUNT];

    int boot_boost_time_ms;

    /* AppProfile defaults */
    struct {
        int min_freq;
        int max_freq;
        int core_cap;
        int gpu_cap;
        int fan_cap;
        int power_cap;
    } defaults;

    /* Features on platform */
    struct {
        bool fan;
    } features;

    /* File descriptors used for hints and app profiles */
    struct {
        int app_max_online_cpus;
        int app_min_online_cpus;
        int app_max_gpu;
        int app_min_gpu;
    } fds;

    /* Switching CPU/EMC freq ratio based on display state */
    bool switch_cpu_emc_limit_enabled;
};

/* Opens power hw module */
void common_power_open(struct powerhal_info *pInfo);

/* Power management setup action at startup.
 * Such as to set default cpufreq parameters.
 */
void common_power_init(struct power_module *module, struct powerhal_info *pInfo);

/* Power management action,
 * upon the system entering interactive state and ready for interaction,
 * often with UI devices
 * OR
 * non-interactive state the system appears asleep, displayi/touch usually turned off.
*/
void common_power_set_interactive(struct power_module *module,
                                    struct powerhal_info *pInfo, int on);

/* PowerHint called to pass hints on power requirements, which
 * may result in adjustment of power/performance parameters of the
 * cpufreq governor and other controls.
*/
void common_power_hint(struct power_module *module, struct powerhal_info *pInfo,
                            power_hint_t hint, void *data);

#endif  //COMMON_POWER_HAL_H
