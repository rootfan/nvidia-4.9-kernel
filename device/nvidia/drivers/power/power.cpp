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

#include "powerhal.h"

static struct powerhal_info *pInfo;
static struct input_dev_map input_devs[] = {
        {-1, "raydium_ts\n"},
        {-1, "touch\n"},
        {-1, "touch_fusion\n"}
       };

static void ardbeg_power_init(struct power_module *module)
{
    /*
    * for pre-O compability
    * remove this after O upgrade
    */
    if (!pInfo) {
        pInfo = new powerhal_info();
        common_power_open(pInfo);
    }

    if (!pInfo) {
        ALOGE("PowerHal: %s: check if failure on device open.", __func__);
        return;
    }
    size_t input_cnt = sizeof(input_devs)/sizeof(struct input_dev_map);
    pInfo->input_devs.insert(pInfo->input_devs.end(),
                    &input_devs[0], &input_devs[input_cnt]);

    common_power_init(module, pInfo);
}

static void ardbeg_power_set_interactive(struct power_module *module, int on)
{
    common_power_set_interactive(module, pInfo, on);
}

static void ardbeg_power_hint(struct power_module *module, power_hint_t hint,
                            void *data)
{
    common_power_hint(module, pInfo, hint, data);
}

static int ardbeg_power_open(const hw_module_t *module, const char *name,
                            hw_device_t **device)
{
    struct power_module *pdev;

    if (strcmp(name, POWER_HARDWARE_MODULE_ID) || (!module))
        return -EINVAL;

    if (!pInfo) {
        pInfo = new powerhal_info();
    }

    pdev = (struct power_module *)calloc(1, sizeof(struct power_module));
    if (!pdev) {
        ALOGE("PowerHal: %s failed to alloc memory for power module interface!", __func__);
        return -ENOMEM;
    }
    memcpy((void *)&pdev->common, (const void *)module, sizeof(hw_module_t));
    pdev->init = ardbeg_power_init,
    pdev->setInteractive = ardbeg_power_set_interactive,
    pdev->powerHint = ardbeg_power_hint,

    *device = (hw_device_t *)pdev;

    common_power_open(pInfo);

    return 0;
}

static struct hw_module_methods_t power_module_methods = {
    .open = ardbeg_power_open,
};

struct power_module HAL_MODULE_INFO_SYM = {
    .common = {
        .tag = HARDWARE_MODULE_TAG,
        .module_api_version = POWER_MODULE_API_VERSION_0_2,
        .hal_api_version = HARDWARE_HAL_API_VERSION,
        .id = POWER_HARDWARE_MODULE_ID,
        .name = "Ardbeg Power HAL",
        .author = "NVIDIA",
        .methods = &power_module_methods,
        .dso = NULL,
        .reserved = {0},
    },

    .init = ardbeg_power_init,
    .setInteractive = ardbeg_power_set_interactive,
    .powerHint = ardbeg_power_hint,
};
