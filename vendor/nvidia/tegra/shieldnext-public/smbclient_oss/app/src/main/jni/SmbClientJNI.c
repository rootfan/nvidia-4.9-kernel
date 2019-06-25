/*=====================================================================
  Copyright (C) NVIDIA, 2018

  This program is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 3 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program; if not, see <http://www.gnu.org/licenses/>.
  =====================================================================*/

#define LOG_NDEBUG 0
#define LOG_TAG "SmbClient-JNI"

#include <jni.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <android/log.h>
#include "include/libsmbclient.h"

#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)
#define LOGW(...) __android_log_print(ANDROID_LOG_WARN, LOG_TAG, __VA_ARGS__)
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGD(...) __android_log_print(ANDROID_LOG_DEBUG, LOG_TAG, __VA_ARGS__)

#define JNI_METHOD(return_type, method_name) \
JNIEXPORT return_type JNICALL              \
      Java_com_nvidia_shield_smbauth_nas_SmbClient_##method_name

#define HOME_ENV_VAR "HOME"
#define SMB_CRED_LEN 64

static char g_username[SMB_CRED_LEN];
static char g_password[SMB_CRED_LEN];
static char g_workgroup[SMB_CRED_LEN];

static void onSmbcAuth(const char *server, const char *share, char *workgroup, int workgrouplen,
                              char *username, int usernamelen, char *password, int passwordlen) {

    strncpy(username, g_username, usernamelen - 1);
    username[usernamelen - 1] = 0;
    strncpy(password, g_password, passwordlen - 1);
    password[passwordlen - 1] = 0;
    strncpy(workgroup, g_workgroup, workgrouplen - 1);
    workgroup[workgrouplen - 1] = 0;

}

static void addSharesToArrayList(JNIEnv *env, int dirhandle, jobject objArr) {
    jclass arrayClass = (*env)->FindClass(env, "java/util/ArrayList");
    if (arrayClass == NULL) return;

    jmethodID addMethod = (*env)->GetMethodID(env, arrayClass, "add", "(Ljava/lang/Object;)Z");
    if (addMethod == NULL) return;

    struct smbc_dirent *dirent = NULL;

    while ((dirent = smbc_readdir(dirhandle)) != NULL) {
        if (strcmp(dirent->name, "") == 0
            || strcmp(dirent->name, ".") == 0
            || strcmp(dirent->name, "..") == 0
            || dirent->smbc_type != SMBC_FILE_SHARE
            || dirent->name[dirent->namelen - 1] == '$') {
            LOGD("Skipping %s", dirent->name);
            continue;
        }
        jobject stringVal = (*env)->NewStringUTF(env, dirent->name);
        (*env)->CallBooleanMethod(env, objArr, addMethod, stringVal);
        (*env)->DeleteLocalRef(env, stringVal);
    }
}

JNI_METHOD(int, nativeGetSharesList)(JNIEnv *env, jclass clazz,
                              jstring serverString, jstring domainString,
                              jstring usernameString, jstring passwordString, jobject outputArraylist) {

    int dirhandle;
    int ret = -1;
    const char* server;
    const char* domain;
    const char* username;
    const char* password;
    char path[64];

    SMBCCTX *smbc_context = smbc_new_context();
    if (smbc_context == NULL) {
        return ret;
    }
    smbc_setDebug(smbc_context, 1);
    smbc_setFunctionAuthData(smbc_context, onSmbcAuth);

    if (smbc_init_context(smbc_context) == NULL) {
        smbc_free_context(smbc_context, 1);
        return ret;
    }

    smbc_set_context(smbc_context);

    server = serverString != NULL ? (*env)->GetStringUTFChars(env, serverString, 0) : NULL;
    domain = domainString != NULL ? (*env)->GetStringUTFChars(env, domainString, 0) : NULL;
    username = usernameString != NULL ? (*env)->GetStringUTFChars(env, usernameString, 0) : NULL;
    password = passwordString != NULL ? (*env)->GetStringUTFChars(env, passwordString, 0) : NULL;

    if (username != NULL) {
        strncpy(g_username, username, SMB_CRED_LEN - 1);
        g_username[SMB_CRED_LEN - 1] = 0;
    }
    if (password != NULL) {
        strncpy(g_password, password, SMB_CRED_LEN - 1);
        g_password[SMB_CRED_LEN - 1] = 0;
    }
    if (domain != NULL) {
        strncpy(g_workgroup, domain, SMB_CRED_LEN - 1);
        g_workgroup[SMB_CRED_LEN - 1] = 0;
    }

    snprintf(path, 64, "smb://%s/", server);

    dirhandle = smbc_opendir(path);

    if (dirhandle < 0) {
        LOGE("Failed to open directory \"%s\" : %d - %s", path, errno, strerror(errno));
        ret = errno;
    } else {
        addSharesToArrayList(env, dirhandle, outputArraylist);
        smbc_closedir(dirhandle);
        ret = 0;
    }

    smbc_free_context(smbc_context, 1);

    (*env)->ReleaseStringUTFChars(env, serverString, server);
    (*env)->ReleaseStringUTFChars(env, domainString, domain);
    (*env)->ReleaseStringUTFChars(env, usernameString, username);
    (*env)->ReleaseStringUTFChars(env, passwordString, password);

    return ret;
}

JNI_METHOD(void, nativeInitSmbConfig)(JNIEnv *env, jclass clazz, jstring homePathString) {
    const char *homePath = homePathString != NULL ? (*env)->GetStringUTFChars(env, homePathString, 0) : NULL;
    setenv(HOME_ENV_VAR, homePath, 1);
    (*env)->ReleaseStringUTFChars(env, homePathString, homePath);
}
