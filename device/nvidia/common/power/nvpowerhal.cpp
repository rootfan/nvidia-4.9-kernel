/*
 * Copyright (C) 2012 The Android Open Source Project
 * Copyright (c) 2012-2017, NVIDIA CORPORATION.  All rights reserved.
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
#define LOG_TAG "powerHAL::common"

#include <hardware/hardware.h>
#include <hardware/power.h>
#include <sys/system_properties.h>

#include "powerhal_parser.h"
#include "powerhal_utils.h"
#include "powerhal.h"

#include "nvos.h"

#ifdef PLATFORM_IS_AFTER_N
#include <phs.h>
#define ATRACE_TAG ATRACE_TAG_GRAPHICS
#include <cutils/trace.h>
#endif

#ifdef POWER_MODE_SET_INTERACTIVE
static int get_system_power_mode(void);
static void set_interactive_governor(int mode);

static const interactive_data_t interactive_data_array[NVCPL_HINT_COUNT+1] =
{
    { "1122000", "65 304000:75 1122000:80", "19000", "20000", "0", "41000", "90" },
    { "1020000", "65 256000:75 1020000:80", "19000", "20000", "0", "30000", "99" },
    { "640000", "65 256000:75 640000:80", "80000", "20000", "2", "30000", "99" },
    { "1020000", "65 256000:75 1020000:80", "19000", "20000", "0", "30000", "99" },
    { "420000", "80",                     "80000", "300000","2", "30000", "99" }
};
#endif

// CPU/EMC ratio table source sysfs
#define CPU_EMC_RATIO_SRC_NODE "/sys/kernel/tegra_cpu_emc/table_src"

static void find_input_device_ids(struct powerhal_info *pInfo)
{
    int i = 0;
    int status;
    size_t count = 0;
    char path[80];
    char name[MAX_CHARS];

    while (1)
    {
        snprintf(path, sizeof(path), "/sys/class/input/input%d/name", i);
        if (access(path, F_OK) < 0)
            break;
        else {
            memset(name, 0, MAX_CHARS);
            sysfs_read(path, name, MAX_CHARS);
            if (name[strlen(name) - 1] == '\n')
                name[strlen(name) - 1] = '\0';
            for (auto &input_dev : pInfo->input_devs) {
                if (input_dev.dev_id >= 0)
                    continue;
                if (strncmp(name, input_dev.dev_name, MAX_CHARS))
                    continue;
                ++count;
                input_dev.dev_id = i;
                ALOGI("find_input_device_ids: %d %s",
                    input_dev.dev_id, input_dev.dev_name);
            }
            ++i;
        }

        if (count == pInfo->input_devs.size())
            break;
    }
}

static int check_hint(struct powerhal_info *pInfo, int hint, uint64_t *t)
{
    struct timespec ts;
    uint64_t time;

    if (hint < NV_POWER_HINT_START || hint >= POWER_HINT_COUNT) {
        ALOGE("Invalid power hint: 0x%x", hint);
        return -1;
    }

    clock_gettime(CLOCK_MONOTONIC, &ts);
    time = ts.tv_sec * 1000 + ts.tv_nsec / 1000000;

    if (pInfo->hint_time[hint] && pInfo->hint_interval[hint] &&
        (time - pInfo->hint_time[hint] < pInfo->hint_interval[hint]))
        return -1;

    *t = time;

    return 0;
}

static void init_default_cpu_hints(power_hint_data_t *hints)
{
    hints[POWER_HINT_INTERACTION] = {           1326000,
                                                PM_QOS_DEFAULT_VALUE,
                                                100};
    hints[POWER_HINT_APP_LAUNCH] = {            INT_MAX,
                                                PM_QOS_DEFAULT_VALUE,
                                                1500};
    hints[POWER_HINT_SHIELD_STREAMING] = {      816000,
                                                PM_QOS_DEFAULT_VALUE,
                                                1000};
    hints[POWER_HINT_HIGH_RES_VIDEO] = {        816000,
                                                PM_QOS_DEFAULT_VALUE,
                                                1000};
    hints[POWER_HINT_VIDEO_DECODE] = {          710000,
                                                PM_QOS_DEFAULT_VALUE,
                                                1000};
    hints[POWER_HINT_MIRACAST] = {              816000,
                                                PM_QOS_DEFAULT_VALUE,
                                                1000};
    hints[POWER_HINT_DISPLAY_ROTATION] = {      1500000,
                                                PM_QOS_DEFAULT_VALUE,
                                                2000};
    hints[POWER_HINT_AUDIO_SPEAKER] = {         512000,
                                                PM_QOS_DEFAULT_VALUE,
                                                1000};
    hints[POWER_HINT_AUDIO_OTHER] = {           512000,
                                                PM_QOS_DEFAULT_VALUE,
                                                1000};
    hints[POWER_HINT_AUDIO_LOW_LATENCY] = {     1000000,
                                                PM_QOS_DEFAULT_VALUE,
                                                1000};
    // VSYNC boost ignores duration
    hints[POWER_HINT_VSYNC] = {                 300000,
                                                PM_QOS_DEFAULT_VALUE,
                                                1};
}

static void init_default_gpu_hints(power_hint_data_t *hints)
{
    hints[POWER_HINT_INTERACTION] = {           540000,
                                                PM_QOS_DEFAULT_VALUE,
                                                2000};
    hints[POWER_HINT_APP_LAUNCH] = {            180000,
                                                PM_QOS_DEFAULT_VALUE,
                                                1500};
    hints[POWER_HINT_DISPLAY_ROTATION] = {      252000,
                                                PM_QOS_DEFAULT_VALUE,
                                                2000};
}

static void init_default_emc_hints(power_hint_data_t *hints)
{
    hints[POWER_HINT_INTERACTION] = {           396000,
                                                PM_QOS_DEFAULT_VALUE,
                                                2000};
    hints[POWER_HINT_APP_LAUNCH] = {            792000,
                                                PM_QOS_DEFAULT_VALUE,
                                                1500};
    hints[POWER_HINT_DISPLAY_ROTATION] = {      400000,
                                                PM_QOS_DEFAULT_VALUE,
                                                2000};
    hints[POWER_HINT_AUDIO_LOW_LATENCY] = {     300000,
                                                PM_QOS_DEFAULT_VALUE,
                                                1000};
}

static void init_default_online_cpu_hints(power_hint_data_t *hints)
{
    hints[POWER_HINT_INTERACTION] = {           2,
                                                PM_QOS_DEFAULT_VALUE,
                                                2000};
    hints[POWER_HINT_MULTITHREAD_BOOST] = {     4,
                                                PM_QOS_DEFAULT_VALUE,
                                                2000};
    hints[POWER_HINT_APP_LAUNCH] = {            2,
                                                PM_QOS_DEFAULT_VALUE,
                                                1500};
    hints[POWER_HINT_SHIELD_STREAMING] = {      2,
                                                PM_QOS_DEFAULT_VALUE,
                                                1000};
    hints[POWER_HINT_HIGH_RES_VIDEO] = {        2,
                                                PM_QOS_DEFAULT_VALUE,
                                                1000};
    hints[POWER_HINT_VIDEO_DECODE] = {          1,
                                                PM_QOS_DEFAULT_VALUE,
                                                1000};
    hints[POWER_HINT_DISPLAY_ROTATION] = {      2,
                                                PM_QOS_DEFAULT_VALUE,
                                                2000};
    hints[POWER_HINT_AUDIO_LOW_LATENCY] = {      4,
                                                PM_QOS_DEFAULT_VALUE,
                                                2000};

}

static void init_default_hint_intervals(struct powerhal_info *pInfo)
{
    pInfo->hint_interval[POWER_HINT_VSYNC] = 0;
    pInfo->hint_interval[POWER_HINT_INTERACTION] = 90;
    pInfo->hint_interval[POWER_HINT_APP_PROFILE] = 200;
    pInfo->hint_interval[POWER_HINT_APP_LAUNCH] = 1500;
    pInfo->hint_interval[POWER_HINT_SHIELD_STREAMING] = 500;
    pInfo->hint_interval[POWER_HINT_HIGH_RES_VIDEO] = 500;
    pInfo->hint_interval[POWER_HINT_VIDEO_DECODE] = 500;
    pInfo->hint_interval[POWER_HINT_MIRACAST] = 500;
    pInfo->hint_interval[POWER_HINT_AUDIO_SPEAKER] = 500;
    pInfo->hint_interval[POWER_HINT_AUDIO_OTHER] = 500;
    pInfo->hint_interval[POWER_HINT_AUDIO_LOW_LATENCY] = 500;
    pInfo->hint_interval[POWER_HINT_DISPLAY_ROTATION] = 200;
    pInfo->hint_interval[POWER_HINT_POWER_MODE] = 0;
}

static void init_default_hint_parameters(struct powerhal_info *pInfo)
{
    for (auto &cpu_cluster : pInfo->cpu_clusters) {
        init_default_cpu_hints(cpu_cluster.hints);
    }
    pInfo->boot_boost_time_ms = 15000;
    init_default_gpu_hints(pInfo->gpu_freq_hints);
    init_default_emc_hints(pInfo->emc_freq_hints);
    init_default_online_cpu_hints(pInfo->online_cpu_hints);
    init_default_hint_intervals(pInfo);
}

static void init_hint_parameters(struct powerhal_info *pInfo)
{
    int ret = -1;
    char hw_name[PROP_VALUE_MAX];

    if (__system_property_get(HARDWARE_TYPE_PROP, hw_name))
        ret = parse_xml(pInfo, hw_name);
    else
        ALOGE("Could not read property %s", HARDWARE_TYPE_PROP);

    if (ret) {
        ALOGW("Initializing hint parameters to default values");
        // Initialize default cluster. This emulates legacy behavior.
        if (pInfo->cpu_clusters.size() == 0) {
            pInfo->cpu_clusters.push_back({});
            pInfo->cpu_clusters[0].pmqos_constraint_path = PMQOS_CONSTRAINT_CPU_FREQ;
            pInfo->cpu_clusters[0].available_freqs_path = "/sys/devices/system/cpu/cpu0/cpufreq/scaling_available_frequencies";
        }
        init_default_hint_parameters(pInfo);
    }
}

void common_power_open(struct powerhal_info *pInfo)
{
    int j;
    int size = 256;
    char *pch;

    if (!pInfo) {
        ALOGE("%s: null argument of powerhal info", __func__);
        return;
    }

    // Initialize timeout poker
    Barrier readyToRun;
    pInfo->mTimeoutPoker = new TimeoutPoker(&readyToRun);
    readyToRun.wait();

    init_hint_parameters(pInfo);
    find_input_device_ids(pInfo);

    // Read available frequencies
    char *buf = (char*)malloc(sizeof(char) * size);

    for (auto &cpu_cluster : pInfo->cpu_clusters) {
        if (access(cpu_cluster.available_freqs_path, R_OK)) {
            ALOGW("Cannot access %s. Certain power hints may not work!",
                        cpu_cluster.available_freqs_path);
            cpu_cluster.num_available_frequencies = 0;
            cpu_cluster.available_frequencies = NULL;
            continue;
        }
        memset(buf, 0, size);
        sysfs_read(cpu_cluster.available_freqs_path, buf, size);

        // Determine number of available frequencies
        pch = strtok(buf, " ");
        cpu_cluster.num_available_frequencies = -1;
        while(pch != NULL)
        {
            pch = strtok(NULL, " ");
            cpu_cluster.num_available_frequencies++;
        }

        // Store available frequencies in a lookup array
        cpu_cluster.available_frequencies = (int*)malloc(sizeof(int)
                        * cpu_cluster.num_available_frequencies);
        sysfs_read(cpu_cluster.available_freqs_path, buf, size);
        pch = strtok(buf, " ");
        for(j = 0; j < cpu_cluster.num_available_frequencies; j++)
        {
            cpu_cluster.available_frequencies[j] = atoi(pch);
            pch = strtok(NULL, " ");
        }
    }

    // Initialize AppProfile defaults
    pInfo->defaults.min_freq = 0;
    pInfo->defaults.max_freq = PM_QOS_DEFAULT_VALUE;
    pInfo->defaults.core_cap = PM_QOS_DEFAULT_VALUE;
    pInfo->defaults.gpu_cap = PM_QOS_DEFAULT_VALUE;
    pInfo->defaults.fan_cap = 70;
    pInfo->defaults.power_cap = 0;

    // Initialize fds
    for (auto &cpu_cluster : pInfo->cpu_clusters) {
        cpu_cluster.fd_app_min_freq = -1;
        cpu_cluster.fd_app_max_freq = -1;
        cpu_cluster.fd_vsync_min_freq = -1;
    }
    pInfo->fds.app_max_online_cpus = -1;
    pInfo->fds.app_min_online_cpus = -1;
    pInfo->fds.app_max_gpu = -1;
    pInfo->fds.app_min_gpu = -1;

    // Initialize features
    pInfo->features.fan = sysfs_exists("/sys/devices/platform/pwm-fan/pwm_cap");

    free(buf);
}

static void set_vsync_min_cpu_freq(struct powerhal_info *pInfo, int enabled)
{
    if (enabled) {
        for (auto &cpu_cluster : pInfo->cpu_clusters)
            if (cpu_cluster.fd_vsync_min_freq == -1)
                cpu_cluster.fd_vsync_min_freq =
                pInfo->mTimeoutPoker->requestPmQos(cpu_cluster.pmqos_constraint_path,
                                    PM_QOS_BOOST_PRIORITY, PM_QOS_DEFAULT_VALUE,
                                    cpu_cluster.hints[POWER_HINT_VSYNC].min);
    } else {
        for (auto &cpu_cluster : pInfo->cpu_clusters)
            if (cpu_cluster.fd_vsync_min_freq >= 0) {
                close(cpu_cluster.fd_vsync_min_freq);
                cpu_cluster.fd_vsync_min_freq = -1;
            }
    }

    ALOGV("%s: set min CPU floor =%i", __func__, pInfo->cpu_clusters[0].hints[POWER_HINT_VSYNC].min);
}

static void set_app_profile_min_cpu_freq(struct powerhal_info *pInfo, int value)
{
    if (value < 0)
        value = pInfo->defaults.min_freq;

    for (auto &cpu_cluster : pInfo->cpu_clusters) {
        if (cpu_cluster.fd_app_min_freq >= 0)
            close(cpu_cluster.fd_app_min_freq);
        cpu_cluster.fd_app_min_freq =
            pInfo->mTimeoutPoker->requestPmQos(cpu_cluster.pmqos_constraint_path,
                                PM_QOS_APP_PROFILE_PRIORITY, PM_QOS_DEFAULT_VALUE, value);
    }
    ALOGV("%s: set min CPU floor =%d", __func__, value);
}

static void set_app_profile_max_cpu_freq_cluster(struct powerhal_info *pInfo, int value,
                cpu_cluster_data_t *cluster)
{
    if (cluster->fd_app_max_freq >= 0)
        close(cluster->fd_app_max_freq);
    cluster->fd_app_max_freq =
        pInfo->mTimeoutPoker->requestPmQos(cluster->pmqos_constraint_path,
                            PM_QOS_APP_PROFILE_PRIORITY, value, PM_QOS_DEFAULT_VALUE);

    ALOGV("%s: set max CPU ceiling =%d", __func__, value);
}

static void set_app_profile_max_cpu_freq(struct powerhal_info *pInfo, int value)
{
    if (value <= 0)
        value = pInfo->defaults.max_freq;

    for (auto &cpu_cluster : pInfo->cpu_clusters)
        set_app_profile_max_cpu_freq_cluster(pInfo, value, &cpu_cluster);
}

static void set_app_profile_max_cpu_freq_percent(struct powerhal_info *pInfo, int percent)
{
    int targetMaxFreq;

    if (percent == PM_QOS_DEFAULT_VALUE)
        percent = 100;

    if (percent <= 0 || percent > 100) {
        ALOGW("%s: invalid percentage =%d", __func__, percent);
        return;
    }
    for (auto &cpu_cluster : pInfo->cpu_clusters) {
        if (cpu_cluster.num_available_frequencies == 0)
            continue;
        targetMaxFreq = percent *
            cpu_cluster.available_frequencies[cpu_cluster.num_available_frequencies - 1] / 100;
        set_app_profile_max_cpu_freq_cluster(pInfo, targetMaxFreq, &cpu_cluster);
    }
}

static void set_app_profile_max_online_cpus(struct powerhal_info *pInfo, int value)
{
    if (value <= 0)
        value = pInfo->defaults.core_cap;

    if (pInfo->fds.app_max_online_cpus >= 0) {
        close(pInfo->fds.app_max_online_cpus);
        pInfo->fds.app_max_online_cpus = -1;
    }
    pInfo->fds.app_max_online_cpus =
        pInfo->mTimeoutPoker->requestPmQos(PMQOS_CONSTRAINT_ONLINE_CPUS, PM_QOS_APP_PROFILE_PRIORITY, value, PM_QOS_DEFAULT_VALUE);

    ALOGV("%s: set max online CPU core =%d", __func__, value);
}

static void set_app_profile_min_online_cpus(struct powerhal_info *pInfo, int value)
{
    if (pInfo->fds.app_min_online_cpus >= 0) {
        close(pInfo->fds.app_min_online_cpus);
        pInfo->fds.app_min_online_cpus = -1;
    }
    pInfo->fds.app_min_online_cpus =
        pInfo->mTimeoutPoker->requestPmQos(PMQOS_CONSTRAINT_ONLINE_CPUS, PM_QOS_APP_PROFILE_PRIORITY, PM_QOS_DEFAULT_VALUE, value);

    ALOGV("%s: set min online CPU core =%d", __func__, value);
}

static void set_app_profile_min_gpu_freq(struct powerhal_info *pInfo, int value)
{
    if (pInfo->fds.app_min_gpu >= 0) {
        close(pInfo->fds.app_min_gpu);
        pInfo->fds.app_min_gpu = -1;
    }
    if (value)
        value = 0;
    else
        value = INT_MAX;

    pInfo->fds.app_min_gpu =
        pInfo->mTimeoutPoker->requestPmQos(PMQOS_CONSTRAINT_GPU_FREQ, PM_QOS_APP_PROFILE_PRIORITY, PM_QOS_DEFAULT_VALUE, value);
}

static void set_prism_control_enable(struct powerhal_info *pInfo, int value)
{
    if (value)
        set_property_int(PRISM_CONTROL_PROP, 1);
    else
        set_property_int(PRISM_CONTROL_PROP, 0);
    ALOGV("%s: set prism enable =%d", __func__, value);
}

static void set_app_profile_max_gpu_freq(struct powerhal_info *pInfo, int value)
{
    if (value <= 0)
        value = pInfo->defaults.gpu_cap;

#ifndef GPU_IS_LEGACY
    if (pInfo->fds.app_max_gpu >= 0) {
        close(pInfo->fds.app_max_gpu);
        pInfo->fds.app_max_gpu = -1;
    }
    pInfo->fds.app_max_gpu =
        pInfo->mTimeoutPoker->requestPmQos(PMQOS_CONSTRAINT_GPU_FREQ, PM_QOS_APP_PROFILE_PRIORITY, value, PM_QOS_DEFAULT_VALUE);
#else
    /* legacy sysfs nodes to throttle GPU on "pre-T124" chips */
    sysfs_write_int("sys/kernel/tegra_cap/cbus_cap_state", 1);
    sysfs_write_int("sys/kernel/tegra_cap/cbus_cap_level", value);
#endif
}

static void set_pbc_power(struct powerhal_info *pInfo, int value)
{
    if (value < 0)
        value = pInfo->defaults.power_cap;

    set_property_int(POWER_CAP_PROP, value);
}

static void set_fan_cap(struct powerhal_info *pInfo, int value)
{
    if (!pInfo->features.fan)
        return;

    if (value < 0)
        value = pInfo->defaults.fan_cap;

    sysfs_write_int("/sys/devices/platform/pwm-fan/pwm_cap", value);
}

static void app_profile_set(struct powerhal_info *pInfo, app_profile_knob *data)
{
    int i;

    for (i = 0; i < APP_PROFILE_COUNT; i++)
    {
        switch (i) {
            case APP_PROFILE_CPU_SCALING_MIN_FREQ:
                set_app_profile_min_cpu_freq(pInfo, data[i]);
                break;
            case APP_PROFILE_CPU_MAX_NORMAL_FREQ_IN_PERCENTAGE:
                //As user operation take the highest priority
                //Other cpu max freq related control should be before it.
                set_app_profile_max_cpu_freq_percent(pInfo, data[i]);
                break;
            case APP_PROFILE_CPU_MAX_CORE:
                set_app_profile_max_online_cpus(pInfo, data[i]);
                break;
            case APP_PROFILE_GPU_CBUS_CAP_LEVEL:
                set_app_profile_max_gpu_freq(pInfo, data[i]);
                break;
            case APP_PROFILE_GPU_SCALING:
                set_app_profile_min_gpu_freq(pInfo, data[i]);
                break;
            case APP_PROFILE_PRISM_CONTROL_ENABLE:
                set_prism_control_enable(pInfo, data[i]);
                break;
            case APP_PROFILE_CPU_MIN_CORE:
                set_app_profile_min_online_cpus(pInfo, data[i]);
                break;
            default:
                break;
        }
    }
}

void common_power_init(struct power_module *module, struct powerhal_info *pInfo)
{
    size_t i;

    if (!pInfo)
        return;

    pInfo->ftrace_enable = get_property_bool("nvidia.hwc.ftrace_enable", false);

    // Boost to max frequency on initialization to decrease boot time
    for (auto &cpu_cluster : pInfo->cpu_clusters)
        if (cpu_cluster.num_available_frequencies > 0)
            pInfo->mTimeoutPoker->requestPmQosTimed(cpu_cluster.pmqos_constraint_path,
                                            PM_QOS_BOOST_PRIORITY,
                                            PM_QOS_DEFAULT_VALUE,
                                            cpu_cluster.available_frequencies[cpu_cluster.num_available_frequencies - 1],
                                            ms2ns(pInfo->boot_boost_time_ms));

    pInfo->switch_cpu_emc_limit_enabled = sysfs_exists(CPU_EMC_RATIO_SRC_NODE);
}

void common_power_set_interactive(struct power_module *module, struct powerhal_info *pInfo, int on)
{
    int i;
    int dev_id;
    char path[80];
    const char* state = (0 == on)?"0":"1";
    int power_mode = -1;

    if (!pInfo)
        return;

    if (!pInfo->no_sclk_boost)
        sysfs_write("/sys/devices/platform/host1x/nvavp/boost_sclk", state);

    for (auto &input_dev : pInfo->input_devs) {
        if (input_dev.dev_id < 0)
            continue;

        dev_id = input_dev.dev_id;
        snprintf(path, sizeof(path), "/sys/class/input/input%d/enabled", dev_id);
        if (!access(path, W_OK)) {
            if (0 == on)
                ALOGI("Disabling input device:%d", dev_id);
            else
                ALOGI("Enabling input device:%d", dev_id);
            sysfs_write(path, state);
        }

        if(pInfo->switch_cpu_emc_limit_enabled) {
            sysfs_write_int(CPU_EMC_RATIO_SRC_NODE, on);
        }
    }

    if (pInfo->no_cpufreq_interactive)
        return;

#ifdef POWER_MODE_SET_INTERACTIVE
    if (on) {
        power_mode = get_system_power_mode();
        if (power_mode < NVCPL_HINT_MAX_PERF || power_mode > NVCPL_HINT_COUNT) {
            ALOGV("%s: no system power mode info, take optimized settings", __func__);
            power_mode = NVCPL_HINT_OPT_PERF;
        }
    } else {
        power_mode = NVCPL_HINT_COUNT;
    }
    set_interactive_governor(power_mode);
#else
    sysfs_write("/sys/devices/system/cpu/cpufreq/interactive/hispeed_freq", (on == 0)?"420000":"624000");
    sysfs_write("/sys/devices/system/cpu/cpufreq/interactive/target_loads", (on == 0)?"45 312000:75 564000:85":"65 228000:75 624000:85");
    sysfs_write("/sys/devices/system/cpu/cpufreq/interactive/above_hispeed_delay", (on == 0)?"80000":"19000");
    sysfs_write("/sys/devices/system/cpu/cpufreq/interactive/timer_rate", (on == 0)?"300000":"20000");
    sysfs_write("/sys/devices/system/cpu/cpufreq/interactive/boost_factor", (on == 0)?"2":"0");
#endif
}

#ifdef POWER_MODE_SET_INTERACTIVE
static int get_system_power_mode(void)
{
    char value[PROPERTY_VALUE_MAX] = { 0 };
    int power_mode = -1;

    property_get("persist.sys.NV_POWER_MODE", value, "");
    if (value[0] != '\0')
    {
        power_mode = atoi(value);
    }

    if (get_property_bool("persist.sys.NV_ECO.STATE.ISECO", false))
    {
        power_mode = NVCPL_HINT_BAT_SAVE;
    }

    return power_mode;
}

static void __sysfs_write(const char *file, const char *data)
{
    if (data != NULL)
    {
        sysfs_write(file, data);
    }
}

static void set_interactive_governor(int mode)
{
    __sysfs_write("/sys/devices/system/cpu/cpufreq/interactive/hispeed_freq",
            interactive_data_array[mode].hispeed_freq);
    __sysfs_write("/sys/devices/system/cpu/cpufreq/interactive/target_loads",
            interactive_data_array[mode].target_loads);
    __sysfs_write("/sys/devices/system/cpu/cpufreq/interactive/above_hispeed_delay",
            interactive_data_array[mode].above_hispeed_delay);
    __sysfs_write("/sys/devices/system/cpu/cpufreq/interactive/timer_rate",
            interactive_data_array[mode].timer_rate);
    __sysfs_write("/sys/devices/system/cpu/cpufreq/interactive/boost_factor",
            interactive_data_array[mode].boost_factor);
    __sysfs_write("/sys/devices/system/cpu/cpufreq/interactive/min_sample_time",
            interactive_data_array[mode].min_sample_time);
    __sysfs_write("/sys/devices/system/cpu/cpufreq/interactive/go_hispeed_load",
            interactive_data_array[mode].go_hispeed_load);
}

static void set_power_mode_hint(struct powerhal_info *pInfo, nvcpl_hint_t *data)
{
    int mode = data[0];
    int status;
    char value[4] = { 0 };

    if (mode < NVCPL_HINT_MAX_PERF || mode > NVCPL_HINT_COUNT)
    {
        ALOGE("%s: invalid hint mode = %d", __func__, mode);
        return;
    }

    if (pInfo->no_cpufreq_interactive)
        return;

    // only set interactive governor parameters when display on
    sysfs_read("/sys/class/backlight/pwm-backlight/brightness", value, sizeof(value));
    status = atoi(value);

    if (status)
    {
        set_interactive_governor(mode);
    }

}
#endif

static void apply_gpu_boost(struct powerhal_info *pInfo, int hint)
{
    pInfo->mTimeoutPoker->requestPmQosTimed(PMQOS_CONSTRAINT_GPU_FREQ,
                                            PM_QOS_BOOST_PRIORITY,
                                            pInfo->gpu_freq_hints[hint].max,
                                            pInfo->gpu_freq_hints[hint].min,
                                            ms2ns(pInfo->gpu_freq_hints[hint].time_ms));
}

static void apply_online_cpus_boost(struct powerhal_info *pInfo, int hint)
{
    pInfo->mTimeoutPoker->requestPmQosTimed(PMQOS_CONSTRAINT_ONLINE_CPUS,
                                            PM_QOS_BOOST_PRIORITY,
                                            pInfo->online_cpu_hints[hint].max,
                                            pInfo->online_cpu_hints[hint].min,
                                            ms2ns(pInfo->online_cpu_hints[hint].time_ms));
}

static void apply_emc_boost(struct powerhal_info *pInfo, int hint)
{
    pInfo->mTimeoutPoker->requestPmQosTimed("/dev/emc_freq_min",
                                            pInfo->emc_freq_hints[hint].min,
                                            ms2ns(pInfo->emc_freq_hints[hint].time_ms));
}

void common_power_hint(struct power_module *module, struct powerhal_info *pInfo,
                            power_hint_t hintId, void *data)
{
    uint64_t t;
    size_t i;

    if (!pInfo)
        return;

    int hint = hintId;
    if (check_hint(pInfo, hint, &t) < 0)
        return;

    switch (hint) {
    case POWER_HINT_VSYNC:
        if (data)
            set_vsync_min_cpu_freq(pInfo, *(int *)data);
        break;
    case POWER_HINT_INTERACTION:
        break;
    case POWER_HINT_MULTITHREAD_BOOST:
    case POWER_HINT_APP_LAUNCH:
    case POWER_HINT_SHIELD_STREAMING:
    case POWER_HINT_HIGH_RES_VIDEO:
    case POWER_HINT_VIDEO_DECODE:
    case POWER_HINT_MIRACAST:
    case POWER_HINT_DISPLAY_ROTATION:
    case POWER_HINT_AUDIO_SPEAKER:
    case POWER_HINT_AUDIO_OTHER:
    case POWER_HINT_AUDIO_LOW_LATENCY:
        for (auto &cpu_cluster : pInfo->cpu_clusters) {
            pInfo->mTimeoutPoker->requestPmQosTimed(cpu_cluster.pmqos_constraint_path,
                                                PM_QOS_BOOST_PRIORITY,
                                                cpu_cluster.hints[hint].max,
                                                cpu_cluster.hints[hint].min,
                                                ms2ns(cpu_cluster.hints[hint].time_ms));
        }

        apply_gpu_boost(pInfo, hint);
        apply_online_cpus_boost(pInfo, hint);
        apply_emc_boost(pInfo, hint);
        break;
    case POWER_HINT_APP_PROFILE:
        if (data) {
            app_profile_set(pInfo, (app_profile_knob*)data);
        } else {
            ALOGW("POWER_HINT_APP_PROFILE: no data, ignore.");
        }
        break;
    case POWER_HINT_CAMERA:
        ALOGW("Camera hint is not supported in PowerHAL");
        break;
    case POWER_HINT_POWER_MODE:
#ifdef POWER_MODE_SET_INTERACTIVE
        if (data) {
            // Set interactive governor parameters according to power mode
            set_power_mode_hint(pInfo, (nvcpl_hint_t *)data);
        } else {
            ALOGE("POWER_HINT_POWER_MODE: no data, ignore.");
        }
#endif
        break;
#ifdef PLATFORM_IS_AFTER_N
    case POWER_HINT_FRAMEWORKS_UI:
        ATRACE_BEGIN("powerhal passing on hints to PHS");
        NvPHSSendThroughputHints(*((int*)data), PHS_FLAG_IMMEDIATE, NvUsecase_ui, NvHintType_TransientCpuLoad, INT_MAX, NVPHS_IMMEDIATE_MODE_MIN_HINT_TIMEOUT_MS, NvUsecase_NULL);
        ATRACE_END();
        break;
    case POWER_HINT_CANCEL_PHS_HINT:
        ATRACE_BEGIN("powerhal passing on hints to PHS");
        NvPHSCancelThroughputHints(*((int*)data),NvUsecase_ui);
        ATRACE_END();
        break;
#endif
    default:
        ALOGE("Unknown power hint: 0x%x", hint);
        break;
    }

    pInfo->hint_time[hint] = t;
}
