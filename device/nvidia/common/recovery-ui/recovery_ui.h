/*
 * Copyright (c) 2016-2017 NVIDIA Corporation.  All rights reserved.
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

#ifndef __RECOVERY_UI_H
#define __RECOVERY_UI_H

#include "ui.h"
#include "screen_ui.h"

#if (PLATFORM_IS_AFTER_LOLLIPOP == 1)
class DefaultRecoveryUI : public ScreenRecoveryUI {
  public:
    DefaultRecoveryUI() :
        consecutive_power_keys(0) {
    }

    KeyAction CheckKey(int key, bool long_press);

  private:
    int consecutive_power_keys;
};
#endif

#ifdef BOARD_SUPPORTS_BILLBOARD
class BillboardRecoveryUI : public DefaultRecoveryUI {
  public:
    BillboardRecoveryUI();

    bool Init(const std::string& locale) override;
    const char *GetResolution();
    void SetZipArchive(ZipArchiveHandle *zip);
  private:
    GRSurface* progressBarEmpty;
    GRSurface* progressBarFill;
    GRSurface* billboard_installing;

    int billboard_frames;   /* total number of billboard frames */
    int billboard_frame;    /* the current billboard frame id */
    int *billboard_showtime;/* the time to show each billboard */
    GRSurface** billboards;  /* surfaces for billboard frames */

    int ExtractBillboards(ZipArchiveHandle *zip);
    int LoadBillboards(int frames);
    void LoadBitmap(const char* filename, GRSurface** surface);

#if (PLATFORM_IS_AFTER_M == 1)
    void draw_background_locked();
    void draw_foreground_locked();
#else
    void draw_background_locked(Icon icon);
    void draw_progress_locked();
#endif

    void ProgressThreadLoop();
};
#endif /* BOARD_SUPPORTS_BILLBOARD */

#endif /* __RECOVERY_UI_H */
