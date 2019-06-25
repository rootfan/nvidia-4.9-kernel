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

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

public class SmbReceiver extends BroadcastReceiver {
    private static final String TAG = SmbReceiver.class.getSimpleName();

    protected static final int JOB_ID = 0x100;

    @Override
    public void onReceive(Context context, Intent intent) {
        Intent jobIntent = new Intent(intent);
        intent.setClass(context, SmbService.class);
        SmbService.enqueueWork(context, SmbService.class, JOB_ID, jobIntent);
    }
}
