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

public enum SmbResult {
    SUCCESS,
    SMB_INIT_FAILURE,
    PERMISSION_DENIED,
    INVALID_URL,
    NON_EXISTENT_URL,
    NOT_ENOUGH_MEM,
    NOT_DIR,
    NO_SERVER_OR_WORKGROUP,

    UNKNOWN
}
