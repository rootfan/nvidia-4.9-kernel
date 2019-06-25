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

package com.nvidia.shield.smbauth.nas;

import android.util.Log;

import java.io.File;
import java.io.FileNotFoundException;
import java.io.PrintStream;
import java.util.List;

public class SmbClient {
    private static final String TAG = SmbClient.class.getSimpleName();
    private static boolean mHasInitted = false;

    public static SmbResult getShares(String server, String domain, String username, String password, List<String> outputShares) {
        int retVal = nativeGetSharesList(server, domain, username, password, outputShares);
        switch (retVal) {
            case 0: //Success
                return SmbResult.SUCCESS;
            case -1: //JNI error
                return SmbResult.SMB_INIT_FAILURE;
            case 13: //EACCES
            case 1: //EPERM
                return SmbResult.PERMISSION_DENIED;
            case 22: //EINVAL
                return SmbResult.INVALID_URL;
            case 2: //ENOENT
                return SmbResult.NON_EXISTENT_URL;
            case 12: //ENOMEM
                return SmbResult.NOT_ENOUGH_MEM;
            case 20: //ENOTDIR
                return SmbResult.NOT_DIR;
            case 19: //ENODEV
                return SmbResult.NO_SERVER_OR_WORKGROUP;
            default:
                return SmbResult.UNKNOWN;

        }
    }

    static {
        System.loadLibrary("smb_jni");
    }

    public static void initSmbConfig(File homeDir) {

        if (mHasInitted)
            return;

        mHasInitted = true;

        File smbDir = new File(homeDir, ".smb");

        if (!smbDir.exists()) {
            if (!smbDir.mkdir()) {
                Log.d(TAG, "SMB dir make failed");
                return;
            }
        }

        File configFile = new File(smbDir, "smb.conf");
        PrintStream stream = null;
        try {
            stream = new PrintStream(configFile);
            stream.println("name resolve order = wins bcast hosts");
            stream.println("client min protocol = NT1");
            stream.println("client max protocol = SMB3");
        } catch (FileNotFoundException e) {
            Log.e(TAG, "Failed to write smb.conf file.", e);
        }
        if (stream != null)
            stream.close();

        nativeInitSmbConfig(homeDir.getAbsolutePath());
    }

    private native static void nativeInitSmbConfig(String homePath);
    private native static int nativeGetSharesList(String server, String domain, String username, String password, List<String> outputShares);

}
