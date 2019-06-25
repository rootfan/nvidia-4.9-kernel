/*
 * Copyright (C) 2012 The Android Open Source Project
 * Copyright (c) 2015, NVIDIA CORPORATION.  All rights reserved.
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

#define LOG_TAG     "bt_restart"
#define LOG_NDEBUG  1

#include <stdio.h>
#include <errno.h>
#include <stdlib.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/epoll.h>

#include <log/log.h>
#include <cutils/uevent.h>
#include <utils/String8.h>

#include <binder/Parcel.h>
#include <binder/IServiceManager.h>
#include <binder/TextOutput.h>

using namespace android;

#define UEVENT_MSG_LEN      2048

#define BT_STATE_RESUMED    "BT_STATE=RESUMED"

#define BT_MGR_SVC_NAME     "bluetooth_manager"

#define BT_MGR_SVC_TRANSACTION_IS_ENABLED   5
#define BT_MGR_SVC_TRANSACTION_ENABLE       6
#define BT_MGR_SVC_TRANSACTION_DISABLE      8

#define BT_MGR_SVC_CHK_TIME_SEC             5   /* 1sec */
#define BT_MGR_SVC_CHK_TIMEOUT              36  /* 180s = 5sec * 30 */

#define BT_WAIT_TIME_SEC                    1   /* 1sec */
#define BT_WAIT_TIMEOUT                     30  /* 30s = 1sec * 30 */

static int epoll_fd;
static int uevent_fd;
sp<IBinder> bt_mgr_svc;
String16 bt_mgr_svc_if_name;

static int do_transact(uint32_t code, Parcel &data, Parcel *reply)
{
    int ret;

    ret = bt_mgr_svc->transact(code, data, reply);
    if (ret < 0)
        return ret;
    return 0;
}

static int bt_mgr_svc_is_enabled(void)
{
    Parcel data, reply;
    int ret;

    data.writeInterfaceToken(bt_mgr_svc_if_name);
    ret = do_transact(BT_MGR_SVC_TRANSACTION_IS_ENABLED, data, &reply);
    if (ret < 0) {
        ALOGE("%s: do_transact failed, code=IS_ENABLED, errno=%d\n",
                __func__, ret);
        return ret;
    }

    /* reply_data[1] is return value of binder transaction. */
    const uint32_t *reply_data = (uint32_t *)reply.data();
    if (reply.dataSize() < 8)
        return -1;
    ALOGV("%s: reply: dataSize=%d, data[0]=0x%08x, [1]=0x%08x\n",
            __func__, reply.dataSize(), reply_data[0], reply_data[1]);

    if (reply_data[1] == 1) /* BT is enabled. */
        return 1;
    return 0;
}

static int bt_mgr_svc_enable(void)
{
    Parcel data, reply;
    int timeout = 0;
    int ret;

    data.writeInterfaceToken(bt_mgr_svc_if_name);
    ret = do_transact(BT_MGR_SVC_TRANSACTION_ENABLE, data, &reply);
    if (ret < 0) {
        ALOGE("%s: do_transact failed, code=ENABLE, errno=%d\n",
                __func__, ret);
        return ret;
    }

    /* reply_data[1] is return value of binder transaction. */
    const uint32_t *reply_data = (uint32_t *)reply.data();
    if (reply.dataSize() < 8)
        return -1;
    ALOGV("%s: reply: dataSize=%d, data[0]=0x%08x, [1]=0x%08x\n",
            __func__, reply.dataSize(), reply_data[0], reply_data[1]);

    if (reply_data[1] == 0) /* BT enable failed. */
        return -1;

    /* Waiting for BT enabled. */
    do {
        sleep(BT_WAIT_TIME_SEC);
        ret = bt_mgr_svc_is_enabled();
        if (ret < 0)
            return ret;
        if (ret == 1) /* BT is enabled. */
            return 0;
    } while (++timeout < BT_WAIT_TIMEOUT);

    return -1;
}

static int bt_mgr_svc_disable(void)
{
    Parcel data, reply;
    int timeout = 0;
    int ret;

    data.writeInterfaceToken(bt_mgr_svc_if_name);
    ret = do_transact(BT_MGR_SVC_TRANSACTION_DISABLE, data, &reply);
    if (ret < 0) {
        ALOGE("%s: do_transact failed, code=DISABLE, errno=%d\n",
                __func__, ret);
        return ret;
    }

    /* reply_data[1] is return value of binder transaction. */
    const uint32_t *reply_data = (uint32_t *)reply.data();
    if (reply.dataSize() < 8)
        return -1;
    ALOGV("%s: reply: dataSize=%d, data[0]=0x%08x, [1]=0x%08x\n",
            __func__, reply.dataSize(), reply_data[0], reply_data[1]);

    if (reply_data[1] == 0) /* BT disable failed. */
        return -1;

    /* Waiting for BT disabled. */
    do {
        sleep(BT_WAIT_TIME_SEC);
        ret = bt_mgr_svc_is_enabled();
        if (ret < 0)
            return ret;
        if (ret == 0) /* BT is disabled. */
            return 0;
    } while (++timeout < BT_WAIT_TIMEOUT);

    return -1;
}

static void bt_mgr_svc_restart(void)
{
    Parcel data, reply;
    int is_enabled;
    int ret;

    ret = bt_mgr_svc_is_enabled();
    if (ret < 0)
        return;
    if (ret == 0) /* Do nothing when BT is not enabled. */
        return;

	ALOGD("Restart Bluetooth\n");

    ret = bt_mgr_svc_disable();
    if (ret < 0) {
        ALOGE("%s: bt_mgr_svc_disable failed\n", __func__);
        return;
    }

    ret = bt_mgr_svc_enable();
    if (ret < 0) {
        ALOGE("%s: bt_mgr_svc_enable failed\n", __func__);
        return;
    }
}

static void handle_uevent(void) {
    char msg[UEVENT_MSG_LEN+2];
    char *cp;
    int n;

    n = uevent_kernel_multicast_recv(uevent_fd, msg, UEVENT_MSG_LEN);
    if (n <= 0) {
        ALOGE("%s: uevent_kernel_multicast_recv failed\n",
            __func__);
        return;
    }
    if (n >= UEVENT_MSG_LEN) {
        ALOGE("%s: overflow the uevent msg\n", __func__);
        return;
    }

    msg[n] = '\0';
    msg[n+1] = '\0';
    cp = msg;

    while (*cp) {
        if (!strncmp(cp, BT_STATE_RESUMED, strlen(BT_STATE_RESUMED))) {
            ALOGV("%s: Got uevent msg \"%s\"\n", __func__, cp);
            bt_mgr_svc_restart();
        }

        while (*cp++) { };
    }
}

static void main_loop(void)
{
    while (1) {
        struct epoll_event ev;
        int nevents;

        nevents = epoll_wait(epoll_fd, &ev, 1, -1);
        if (nevents < 0) {
            if (errno == EINTR)
                continue;

            ALOGE("%s: epoll_wait failed, errno=%d\n", __func__, errno);
            break;
        }

        if (ev.data.fd == uevent_fd)
            handle_uevent();
    }
}

static int uevent_init(void)
{
    int ret;

    uevent_fd = uevent_open_socket(64*1024, true);
    if (uevent_fd < 0) {
        ALOGE("%s: uevent_open_socket failed\n", __func__);
        return -1;
    }

    fcntl(uevent_fd, F_SETFL, O_NONBLOCK);
    return 0;
}

static int epoll_init(void)
{
    struct epoll_event ev;

	epoll_fd = epoll_create(1);
    if (epoll_fd < 0) {
        ALOGE("%s: epoll_create failed, errno=%d\n", __func__, errno);
        return -1;
    }

    ev.events = EPOLLIN;
    ev.data.fd = uevent_fd;
    if (epoll_ctl(epoll_fd, EPOLL_CTL_ADD, uevent_fd, &ev) < 0) {
        ALOGE("%s: epoll_ctl failed, errno=%d\n", __func__, errno);
        return -1;
    }
    return 0;
}

static int bt_mgr_svc_init(void)
{
    String16 svc_name(BT_MGR_SVC_NAME);
    Parcel data, reply;
    int timeout = 0;
    int ret;

    /* bluetooth manager service is available after Android boot. */
    do {
        bt_mgr_svc = defaultServiceManager()->checkService(svc_name);
        if (bt_mgr_svc != NULL)
	    break;
	sleep(BT_MGR_SVC_CHK_TIME_SEC);
    } while (++timeout < BT_MGR_SVC_CHK_TIMEOUT);

    if (bt_mgr_svc == NULL) {
        ALOGE("%s: No %s service\n", __func__, BT_MGR_SVC_NAME);
        return -1;
    }
    ALOGD("Found %s service\n", BT_MGR_SVC_NAME);

    ret = do_transact(IBinder::INTERFACE_TRANSACTION, data, &reply);
    if (ret < 0) {
        ALOGE("%s: do_transact failed, code=TRANSACTION, errno=%d\n",
                __func__, ret);
        return ret;
    }

    bt_mgr_svc_if_name = reply.readString16();
    ALOGV("%s: bt_mgr_svc_if_name=%s\n", __func__,
            String8(bt_mgr_svc_if_name).string());
    return 0;
}

int main(int argc, char **argv)
{
    int ret;

    ret = uevent_init();
    if (ret < 0)
        return ret;

    ret = epoll_init();
    if (ret < 0)
        return ret;

    ret = bt_mgr_svc_init();
    if (ret < 0)
        return ret;

    main_loop();
    return 0;
}
