/*
 * Copyright (C) 2008 The Android Open Source Project
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

/*
 * Copyright (c) 2008-2017, NVIDIA CORPORATION.  All rights reserved.
 */

#define LOG_TAG "lights"

#include <cutils/log.h>

#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <stdbool.h>
#include <errno.h>
#include <fcntl.h>
#include <dirent.h>

#include <sys/ioctl.h>
#include <sys/types.h>

#include <hardware/lights.h>
#include <hardware/hardware.h>

#define DEFAULT_LOW_PERSISTENCE_MODE_BRIGHTNESS 255

static pthread_mutex_t g_lock = PTHREAD_MUTEX_INITIALIZER;
static int g_last_backlight_mode = BRIGHTNESS_MODE_USER;

char const*const BL_PATH = "/sys/class/backlight";

static int write_int(char const *path, int value)
{
    int fd;
    static int already_warned = -1;
    fd = open(path, O_RDWR);
    if (fd >= 0) {
        char buffer[20];
        int bytes = sprintf(buffer, "%d\n", value);
        int amt = write(fd, buffer, bytes);
        close(fd);
        return amt == -1 ? -errno : 0;
    } else {
        if (already_warned == -1) {
            ALOGE("write_int failed to open %s\n", path);
            already_warned = 1;
        }
        return -errno;
    }
}

static int rgb_to_brightness(struct light_state_t const *state)
{
    int color = state->color & 0x00ffffff;
    return ((77 * ((color >> 16) & 0x00ff))
        + (150 * ((color >> 8) & 0x00ff)) +
        (29 * (color & 0x00ff))) >> 8;
}

static int set_light_backlight(struct light_device_t *dev,
                   struct light_state_t const *state)
{
    int err = 0;
    int brightness = rgb_to_brightness(state);
    bool lp_mode = state->brightnessMode == BRIGHTNESS_MODE_LOW_PERSISTENCE;
    DIR *bl_dir = NULL;
    struct dirent *bl_nodes;
    char path[512];

    bl_dir = opendir(BL_PATH);
    if (!bl_dir) {
        ALOGE("set_light_backlight failed to open bl path : %s\n", BL_PATH);
        return -errno;
    }

    pthread_mutex_lock(&g_lock);
    while((bl_nodes = readdir(bl_dir)) != NULL)
    {
        if (bl_nodes->d_name[0] == '.')
                continue;

        /* If not in low-persistence mode and if it's enabled (or)
         * if in low-persistence mode and if it's not enabled,
         * update the sysfs node and brightness accordingly
         */
        if ((g_last_backlight_mode != state->brightnessMode && lp_mode) ||
            (g_last_backlight_mode == BRIGHTNESS_MODE_LOW_PERSISTENCE &&
                                        !lp_mode)) {

                snprintf(path, sizeof(path), "%s/%s/%s", BL_PATH,
                                bl_nodes->d_name, "low_persistence");
                if ((err = write_int(path, lp_mode)) != 0) {
                        ALOGE("%s: Failed to write %s: %s\n", __FUNCTION__,
                              path, strerror(err));
                }
        }
        /* Set brightness to default only for low-persistence mode.
         * If not, brightness should be set from userspace.
         */
        if (lp_mode)
                brightness = DEFAULT_LOW_PERSISTENCE_MODE_BRIGHTNESS;

        if (!err) {
                snprintf(path, sizeof(path), "%s/%s/%s", BL_PATH,
                                bl_nodes->d_name, "brightness");
                err = write_int(path, brightness);
        }
    }
    g_last_backlight_mode = state->brightnessMode;
    closedir(bl_dir);
    pthread_mutex_unlock(&g_lock);

    return err;
}

/** Close the lights device */
static int close_lights(struct light_device_t *dev)
{
    if (dev)
        free(dev);
    return 0;
}

/** Open a new instance of a lights device using name */
static int open_lights(const struct hw_module_t *module, char const *name,
               struct hw_device_t **device)
{
    pthread_t lighting_poll_thread;

    int (*set_light) (struct light_device_t *dev,
              struct light_state_t const *state);

    if (0 == strcmp(LIGHT_ID_BACKLIGHT, name))
        set_light = set_light_backlight;
    else
        return -EINVAL;

    pthread_mutex_init(&g_lock, NULL);

    struct light_device_t *dev = malloc(sizeof(struct light_device_t));
    memset(dev, 0, sizeof(*dev));

    dev->common.tag = HARDWARE_DEVICE_TAG;
    dev->common.version = LIGHTS_DEVICE_API_VERSION_2_0;
    dev->common.module = (struct hw_module_t *)module;
    dev->common.close = (int (*)(struct hw_device_t *))close_lights;
    dev->set_light = set_light;

    *device = (struct hw_device_t *)dev;

    return 0;
}

static struct hw_module_methods_t lights_methods =
{
    .open =  open_lights,
};

/*
 * The backlight Module
 */
struct hw_module_t HAL_MODULE_INFO_SYM =
{
    .tag = HARDWARE_MODULE_TAG,
    .version_major = 1,
    .version_minor = 0,
    .id = LIGHTS_HARDWARE_MODULE_ID,
    .name = "NVIDIA Ardbeg lights module",
    .author = "NVIDIA",
    .methods = &lights_methods,
};
