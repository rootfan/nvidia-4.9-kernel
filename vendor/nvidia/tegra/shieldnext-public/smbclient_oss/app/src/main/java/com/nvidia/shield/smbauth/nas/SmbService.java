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

import android.content.Intent;
import android.os.Bundle;
import android.os.ResultReceiver;
import android.support.annotation.NonNull;
import android.support.v4.app.JobIntentService;
import android.util.Log;

import java.util.ArrayList;

import static com.nvidia.shield.smbauth.settings.NetworkStorageLoginActivity.*;

public class SmbService extends JobIntentService {
    private static final String TAG = SmbService.class.getSimpleName();

    @Override
    protected void onHandleWork(@NonNull Intent intent) {
        ResultReceiver resultReceiver = intent.getParcelableExtra("receiver");
        SmbClient.initSmbConfig(getDir("home", MODE_PRIVATE));

        ArrayList<String> availableShares, storageList;
        Bundle returnBundle = new Bundle();

        storageList = intent.getStringArrayListExtra(EXTRAS_STORAGE_LIST);
        Log.d(TAG, "Storage list = " + storageList);
        if (storageList != null) {
            SmbResult result;
            String hostname, address, username, password, domain;
            for (String storage : storageList) {
                Bundle storageBundle = intent.getBundleExtra(storage);
                result = SmbResult.UNKNOWN;

                hostname = storageBundle.getString(EXTRAS_HOSTNAME);
                address = storageBundle.getString(EXTRAS_ADDRESS);
                domain = storageBundle.getString(EXTRAS_DOMAIN);
                username = storageBundle.getString(EXTRAS_USERNAME);
                password = storageBundle.getString(EXTRAS_PASSWORD);
                Log.d(TAG, "Storage = [" + hostname + "(" + address + "), " + domain + ", " + username + ", <" + password.length() + " character password>]");
                availableShares = new ArrayList<>();

                if ((address != null || hostname != null) && domain != null && username != null && password != null) {
                    result = SmbClient.getShares(address == null ? hostname : address, domain, username, password, availableShares);
                }
                Log.d(TAG, "Result is " + result.toString() + ", shares = " + availableShares);
                Bundle resultBundle = new Bundle();
                resultBundle.putStringArrayList(EXTRAS_SHARES_LIST, availableShares);
                resultBundle.putInt(EXTRAS_SMB_RESULT, result.ordinal());
                returnBundle.putBundle(storage, resultBundle);
            }
            returnBundle.putStringArrayList(EXTRAS_STORAGE_LIST, storageList);
            resultReceiver.send(0, returnBundle); // Success
        } else {
            Log.d(TAG, "Failure");
            returnBundle.putStringArrayList(EXTRAS_STORAGE_LIST, new ArrayList<>());
            resultReceiver.send(1, returnBundle); // Failure
        }
    }
}
