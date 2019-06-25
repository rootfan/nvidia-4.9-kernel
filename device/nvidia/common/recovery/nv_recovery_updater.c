/*
 * Copyright (c) 2011 NVIDIA Corporation.  All rights reserved.
 *
 * NVIDIA Corporation and its licensors retain all intellectual property
 * and proprietary rights in and to this software, related documentation
 * and any modifications thereto.  Any use, reproduction, disclosure or
 * distribution of this software and related documentation without an express
 * license agreement from NVIDIA Corporation is strictly prohibited.
 */
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <ctype.h>
#include <errno.h>
#include "edify/expr.h"
#include "minzip/Zip.h"
#include "updater/updater.h"
#include "fs_mgr.h"

#define BLK_DEVICE_MAX (128)
#define BUFFER_SIZE (1024)
#define RECOVERY_FSTAB_PATH "/etc/recovery.fstab"

// Return 1 if the path exists, 0 otherwise
static int FileExists(const char* path) {
  if (path && (access(path, F_OK) != -1)) {
    return 1;
  }
  return 0;
}

// Parses fstab file to find a mapping from a mount path to block device path
// Since Android 4.3 Google changes the formatting of the fstab file to be of unified format.
// More info: http://source.android.com/devices/tech/storage/
//
// name: For logging purposes log is done with this format ("%s: log...", name)
// mount_path: Path where the block device is mounted
// device_path: Output parameter for the block device path
//
// return: 0 if the mount path found, -1 otherwise
static int GetDevicePath_UnifiedFstab(const char* name, char *mount_path, char *device_path)
{
  if (!mount_path || !device_path) {
    fprintf(stderr, "%s: mount_path or device_path is NULL.\n", name);
    return -1;
  }

  // Parsed fstab file
  struct fstab *fstab;
  // Parse the file using Google's library
  fstab = fs_mgr_read_fstab(RECOVERY_FSTAB_PATH);

  if (!fstab) {
    fprintf(stderr, "%s: Not a valid unified fstab file: %s.\n", name, RECOVERY_FSTAB_PATH);
    return -1;
  }

  fprintf(stderr, "%s: there are %d mounted block device..\n", \
          name, fstab->num_entries);

  // Iterate through parsed fstab to find the path
  int i;
  for (i = 0 ; i < fstab->num_entries ; i++) {
    // Found corresponding mount point
    if (!strcmp((fstab->recs[i]).mount_point, mount_path)) {
      strcpy(device_path, (fstab->recs[i]).blk_device);
      fprintf(stderr, "%s: found device_blk_path for %s at %s.\n", \
              name, mount_path, (fstab->recs[i]).blk_device);
      fs_mgr_free_fstab(fstab);
      return 0;
    }
    fprintf(stderr, "%s: mount_point[%d] :%s.\n", name,i, fstab->recs[i].mount_point);
  }

  fprintf(stderr, "%s: couldn't find a block device for : %s.\n", name, mount_path);
  fs_mgr_free_fstab(fstab);
  return -1;
}

static int GetDevicePath_NonUnifiedFstab(const char* name, char *mount_path, char *device_path) {
  if (!mount_path || !device_path) {
    fprintf(stderr, "%s: mount_path or device_path is NULL.\n", name);
    return -1;
  }

  FILE* fstab = fopen(RECOVERY_FSTAB_PATH, "r");
  if (!fstab) {
    fprintf(stderr, "%s: Couldn't fopen(%s).\n", name, RECOVERY_FSTAB_PATH);
    return -1;
  }

  fprintf(stderr, "%s: Trying to parse fstab file as non-unified.\n", name);

  char *buffer;
  buffer = malloc(BUFFER_SIZE);
  if (!buffer) {
    fclose(fstab);
    return -1;
  }

  while (fgets(buffer, BUFFER_SIZE, fstab)) {
    // Trim whitespace at the beginning of a line
    int i;
    for (i = 0; buffer[i] && isspace(buffer[i]); i++);

    // Skip commented line or empty line
    if (buffer[i] == '\0' || buffer[i] == '#')
      continue;

    // Parse
    char* mount_point = strtok(buffer+i, " \t\n");

    // Found the mount path on fstab, retrieve the block device path
    if (mount_point && (!strcmp(mount_point, mount_path))) {
      char* fs_type = strtok(NULL, " \t\n");
      char* device = strtok(NULL, " \t\n");
      strcpy(device_path, device);
      free(buffer);
      fclose(fstab);
      return 0;
    }
  }

  fprintf(stderr, "%s: Couldn't find device path for /staging partition.\n", name);
  fprintf(stderr, "%s: Is the fstab of a valid non-unified format?\n", name);
  free(buffer);
  fclose(fstab);

  return -1;
}

/*  copies the blob file to staging partition */
Value* NvCopyBlobToUSP(const char* name, State* state,
                       int argc, Expr* argv[]) {
  if (argc != 2) {
    return ErrorAbort(state, "%s() expects 2 args, but received %d arguments.", \
                      name, argc);
  }

  char* zip_path;
  char* mount_path;
  char block_device_path[BLK_DEVICE_MAX];

  if (ReadArgs(state, argv, 2, &zip_path, &mount_path) < 0) {
    fprintf(stderr, "%s: could not successfully parse the given arguments.\n", name);
    return NULL;
  }

  if (!mount_path || !zip_path) {
    fprintf(stderr, "%s: mount_path or zip_path is NULL.\n", name);
    goto fail;
  }

  ZipArchive* za = ((UpdaterInfo*)(state->cookie))->package_zip;
  const ZipEntry* entry = mzFindZipEntry(za, zip_path);
  if (!entry) {
    fprintf(stderr, "%s: no %s in the package.\n", name, zip_path);
    goto fail;
  }

  if (!FileExists(RECOVERY_FSTAB_PATH)) {
    fprintf(stderr, "%s: fstab file doesn't exist: %s.\n", name, RECOVERY_FSTAB_PATH);
    goto fail;
  }

  // Given a mount path, return the actual path of the device mounted
  // Assume the fstab is of unified format, if it fails, try to parse it as non-unified.
  if (GetDevicePath_UnifiedFstab(name, mount_path, block_device_path)) {
    if (GetDevicePath_NonUnifiedFstab(name, mount_path, block_device_path)) {
      fprintf(stderr, "%s: couldn't get the block device path for: %s.\n", \
              name, mount_path);
      return NULL;
    }
    fprintf(stderr, "%s: Non-Unified fstab file is parsed successfully!\n", name);
  }
  else {
    fprintf(stderr, "%s: Unified fstab file is parsed successfully!\n", name);
  }

  FILE* f = fopen(block_device_path, "wb");
  int fd;

  if (f == NULL) {
    fprintf(stderr, "%s: can't open %s for write: %s\n",
            name, block_device_path, strerror(errno));
    goto fail;
  }

  fd = fileno(f);

  int ret;
  ret = mzExtractZipEntryToFile(za, entry, fd);
  close(fd);

 fail:
  if (zip_path) {
    free(zip_path);
  }

  if (mount_path) {
    free(mount_path);
  }

  if (!ret) {
    fprintf(stderr, "%s: can't extract the zip file to %s.\n", name, block_device_path);
    return NULL;
  }
  return StringValue(strdup("successful."));
}

void Register_libnvrecoveryupdater() {
  RegisterFunction("nv_copy_blob_file",NvCopyBlobToUSP);
}
