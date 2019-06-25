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

#include <linux/input.h>
#include <sys/stat.h>
#include <errno.h>
#include <minui/minui.h>
#include <string.h>
#include <fcntl.h>
#include <cutils/properties.h>
#include <utils/Log.h>

#include <fs_mgr.h>
#include "roots.h"
#include "common.h"
#include "device.h"
#include "screen_ui.h"
#include "ui.h"
#include <ext4_utils/make_ext4fs.h>
extern "C" {
#include <ext4_utils/wipe.h>
}
#include <png.h>
#include "recovery_ui.h"

#define SURFACE_DATA_ALIGNMENT 8

static GRSurface* malloc_surface(size_t data_size) {
    size_t size = sizeof(GRSurface) + data_size + SURFACE_DATA_ALIGNMENT;
    unsigned char* temp = reinterpret_cast<unsigned char*>(malloc(size));
    if (temp == NULL) return NULL;
    GRSurface* surface = reinterpret_cast<GRSurface*>(temp);
    surface->data = temp + sizeof(GRSurface) +
        (SURFACE_DATA_ALIGNMENT - (sizeof(GRSurface) % SURFACE_DATA_ALIGNMENT));
    return surface;
}

static int open_png(const char* name, png_structp* png_ptr, png_infop* info_ptr,
                    png_uint_32* width, png_uint_32* height, png_byte* channels) {
    char resPath[256];
    unsigned char header[8];
    int result = 0;
    int color_type, bit_depth;
    size_t bytesRead;

    snprintf(resPath, sizeof(resPath)-1, "/res/images/%s.png", name);
    resPath[sizeof(resPath)-1] = '\0';
    FILE* fp = fopen(resPath, "rb");

    if (fp == NULL) {
        /* try "/tmp/images/%s.png" */
        snprintf(resPath, sizeof(resPath)-1, "/tmp/images/%s.png", name);
        resPath[sizeof(resPath)-1] = '\0';
        fp = fopen(resPath, "rb");
    }

    if (fp == NULL) {
        result = -1;
        goto exit;
    }

    bytesRead = fread(header, 1, sizeof(header), fp);
    if (bytesRead != sizeof(header)) {
        result = -2;
        goto exit;
    }

    if (png_sig_cmp(header, 0, sizeof(header))) {
        result = -3;
        goto exit;
    }

    *png_ptr = png_create_read_struct(PNG_LIBPNG_VER_STRING, NULL, NULL, NULL);
    if (!*png_ptr) {
        result = -4;
        goto exit;
    }

    *info_ptr = png_create_info_struct(*png_ptr);
    if (!*info_ptr) {
        result = -5;
        goto exit;
    }

    if (setjmp(png_jmpbuf(*png_ptr))) {
        result = -6;
        goto exit;
    }

    png_init_io(*png_ptr, fp);
    png_set_sig_bytes(*png_ptr, sizeof(header));
    png_read_info(*png_ptr, *info_ptr);

    png_get_IHDR(*png_ptr, *info_ptr, width, height, &bit_depth,
            &color_type, NULL, NULL, NULL);

    *channels = png_get_channels(*png_ptr, *info_ptr);

    if (bit_depth == 8 && *channels == 3 && color_type == PNG_COLOR_TYPE_RGB) {
        // 8-bit RGB images: great, nothing to do.
    } else if (bit_depth == 8 && *channels == 4 && color_type == PNG_COLOR_TYPE_RGBA) {
        // 8-bit RGBA images: great, nothing to do.
    }else if (bit_depth <= 8 && *channels == 1 && color_type == PNG_COLOR_TYPE_GRAY) {
        // 1-, 2-, 4-, or 8-bit gray images: expand to 8-bit gray.
        png_set_expand_gray_1_2_4_to_8(*png_ptr);
    } else if (bit_depth <= 8 && *channels == 1 && color_type == PNG_COLOR_TYPE_PALETTE) {
        // paletted images: expand to 8-bit RGB.  Note that we DON'T
        // currently expand the tRNS chunk (if any) to an alpha
        // channel, because minui doesn't support alpha channels in
        // general.
        png_set_palette_to_rgb(*png_ptr);
        *channels = 3;
    } else {
        fprintf(stderr, "minui doesn't support PNG depth %d channels %d color_type %d (%s)\n",
                bit_depth, *channels, color_type, name);
        result = -7;
        goto exit;
    }

    return result;

  exit:
    if (result < 0) {
        png_destroy_read_struct(png_ptr, info_ptr, NULL);
    }
    if (fp != NULL) {
        fclose(fp);
    }

    return result;
}

// "display" surfaces are transformed into the framebuffer's required
// pixel format (currently only RGBX is supported) at load time, so
// gr_blit() can be nothing more than a memcpy() for each row.  The
// next two functions are the only ones that know anything about the
// framebuffer pixel format; they need to be modified if the
// framebuffer format changes (but nothing else should).

// Allocate and return a GRSurface* sufficient for storing an image of
// the indicated size in the framebuffer pixel format.
static GRSurface* init_display_surface(png_uint_32 width, png_uint_32 height) {
    GRSurface* surface = malloc_surface(width * height * 4);
    if (surface == NULL) return NULL;

    surface->width = width;
    surface->height = height;
    surface->row_bytes = width * 4;
    surface->pixel_bytes = 4;

    return surface;
}

// Copy 'input_row' to 'output_row', transforming it to the
// framebuffer pixel format.  The input format depends on the value of
// 'channels':
//
//   1 - input is 8-bit grayscale
//   3 - input is 24-bit RGB
//   4 - input is 32-bit RGBA/RGBX
//
// 'width' is the number of pixels in the row.
static void transform_rgb_to_draw(unsigned char* input_row,
                                  unsigned char* output_row,
                                  int channels, int width) {
    int x;
    unsigned char* ip = input_row;
    unsigned char* op = output_row;

    switch (channels) {
        case 1:
            // expand gray level to RGBX
            for (x = 0; x < width; ++x) {
                *op++ = *ip;
                *op++ = *ip;
                *op++ = *ip;
                *op++ = 0xff;
                ip++;
            }
            break;

        case 3:
            // expand RGBA to RGBX
            for (x = 0; x < width; ++x) {
                *op++ = *ip++;
                *op++ = *ip++;
                *op++ = *ip++;
                *op++ = 0xff;
            }
            break;

        case 4:
            // copy RGBA to RGBX
            memcpy(output_row, input_row, width*4);
            break;
    }
}

/* assume RGBA only, with channels == 4 */
#define BLEND(alpha, v1, v2)	(((alpha)*(v1)+(255-(alpha))*(v2)) >> 8)
static void composite_rgba_to_draw(unsigned char *input_row,
                                   unsigned char *output_row,
                                   int width) {
    uint32_t *ip = (uint32_t *)input_row;
    uint32_t *op = (uint32_t *)output_row;
    for (int x = 0; x < width; x++, ip++, op++) {
        uint32_t alpha = (*ip >> 24) & 0xff;
        uint32_t rb = BLEND(alpha, (*ip & 0x00ff00ff) >> 0, (*op & 0x00ff00ff) >> 0);
        uint32_t ga = BLEND(alpha, (*ip & 0xff00ff00) >> 8, (*op & 0xff00ff00) >> 8);
        *op = (rb & 0x00ff00ff) | ((ga << 8) & 0xff00ff00);
    }
}

static int select_locale(const char* loc, std::string *locale) {
    if (locale == NULL) return 0;

    if (strcmp(loc, locale->c_str()) == 0) return 1;

    // if loc does *not* have an underscore, and it matches the start
    // of locale, and the next character in locale *is* an underscore,
    // that's a match.  For instance, loc == "en" matches locale ==
    // "en_US".

    int i;
    for (i = 0; loc[i] != 0 && loc[i] != '_'; ++i);
    if (loc[i] == '_') return 0;

    return (strncmp(locale->c_str(), loc, i) == 0 && (locale->c_str())[i] == '_');
}

static int create_billboard_surface(const char *name,
                                        std::string *locale,
                                        int *pShowtime,
                                        GRSurface **pSurface) {
    GRSurface* surface = NULL;
    int result = 0;
    png_structp png_ptr = NULL;
    png_infop info_ptr = NULL;
    png_uint_32 width, height;
    png_byte channels;
    png_textp text;
    unsigned char* p_row;
    unsigned int y;
    int i, num_text, frames = 1, lframe = 0, showtime = 10;

    *pSurface = NULL;

    /* locale default to en_US */
    if (locale == NULL)
        locale->assign("en_US");

    result = open_png(name, &png_ptr, &info_ptr, &width, &height, &channels);
    if (result < 0) return result;

    if (png_get_text(png_ptr, info_ptr, &text, &num_text)) {
        for (i = 0; i < num_text; i++) {
            const char *k = text[i].key;
            const char *v = text[i].text;

            if (k == NULL || v == NULL)
                continue;

            if (strcmp(k, "frames") == 0)
                frames = atoi(v);
            else if (strcmp(k, "showtime") == 0)
                showtime = atoi(v);
            else if (select_locale(k, locale))
                lframe = atoi(v);
            else
                continue;
        }

        /* search again with default locale */
        if (lframe == 0) {
            locale->assign("en_US");
            for (i = 0; i < num_text; i++) {
                const char *k = text[i].key;
                const char *v = text[i].text;

                if (k == NULL || v == NULL)
                    continue;

                if (select_locale(k, locale))
                    lframe = atoi(v);
            }
        }
    }

    if (height % frames != 0) {
        printf("bad height (%d) for frame count (%d)\n", height, frames);
        result = -9;
        goto exit;
    }

    if (showtime < 1 || showtime > 100) {
        printf("showtime (%d seconds) is absurd, default to 10\n", showtime);
        showtime = 10;
    }

    if ((frames > 1 && lframe < 1) || lframe >= frames) {
        printf("locale frame (%d) out of range (0, %d)\n", lframe, frames);
        result = -9;
        goto exit;
    }

    printf("%s: frames=%d, showtime=%d, lframe=%d, locale=%s\n", name,
                    frames, showtime, lframe, locale);

    height = height / frames;

    surface = init_display_surface(width, height);
    if (surface == NULL) {
        result = -8;
        goto exit;
    }

#if defined(RECOVERY_ABGR) || defined(RECOVERY_BGRA)
    png_set_bgr(png_ptr);
#endif

    p_row = reinterpret_cast<unsigned char*>(malloc(width * channels));
    for (y = 0; y < height; ++y) {
        png_read_row(png_ptr, p_row, NULL);
        transform_rgb_to_draw(p_row, surface->data + y * surface->row_bytes, channels, width);
    }

    /* now skip to the locale frame and composite (assuming RGBA) */
    if (lframe && channels == 4) {
        for (y = height; y < lframe * height; y++)
            png_read_row(png_ptr, p_row, NULL);

        for (y = 0; y < height; y++) {
            png_read_row(png_ptr, p_row, NULL);
            composite_rgba_to_draw(p_row, surface->data + y * surface->row_bytes, width);
        }
    }

    free(p_row);

    *pSurface = surface;

    if (pShowtime)
        *pShowtime = showtime;

exit:
    png_destroy_read_struct(&png_ptr, &info_ptr, NULL);
    if (result < 0 && surface != NULL) free(surface);
    return result;
}

#define ASSUMED_BILLBOARD_PATH          "META-INF/com/nvidia/shield/billboard"
#define MAX_BILLBOARD_IMAGES            100

/* try to find the prefix to the image files based on sku and resolution,
 * e.g. given sku="u12571", resolution="1080p", it will look for the files
 * in the order below and return the prefix to the files.
 *
 *   image_u12571_1080p_0.png
 *   image_1080p_0.png
 *   image_0.png
 */
static char *find_prefix(ZipArchiveHandle *zip,
                            const char *sku,
                            const char *resolution) {
    char prefix[256];
    ZipEntry entry;
    ZipString entry_name;

    /* resolution default to 720p if not specified */
    if (resolution == NULL)
        resolution = "720p";

    if (sku)
        snprintf(prefix, 255, "%s/image_%s_%s_0.png",
                ASSUMED_BILLBOARD_PATH, sku, resolution);
    else
        snprintf(prefix, 255, "%s/image_%s_0.png",
                ASSUMED_BILLBOARD_PATH, resolution);

    entry_name.name = (const uint8_t *) prefix;
    entry_name.name_length = (uint16_t) strlen(prefix);

    if (FindEntry(zip, entry_name, &entry))
        goto found;

    /* try without resolution */
    snprintf(prefix, 255, "%s/image_0.png", ASSUMED_BILLBOARD_PATH);

    entry_name.name = (const uint8_t *) prefix;
    entry_name.name_length = (uint16_t) strlen(prefix);

    if (FindEntry(zip, entry_name, &entry))
        goto found;

    return NULL;

found:
    return strndup(prefix, strlen(prefix) - strlen("_0.png"));
}

BillboardRecoveryUI::BillboardRecoveryUI() :
    billboard_frames(0),
    billboard_frame(-1),
    billboard_showtime(nullptr),
    billboards(nullptr)
{
}

bool BillboardRecoveryUI::Init(const std::string& locale) {

    ScreenRecoveryUI::Init(locale_);

    int result, showtime;
    char filename[256];
    GRSurface* surface;
    LoadBitmap("progress_fill", &progressBarFill);
    LoadBitmap("progress_empty", &progressBarEmpty);

    snprintf(filename, 255, "billboard_installing_%s", GetResolution());
    result = create_billboard_surface(filename, &locale_,
                                      &showtime, &surface);
    billboard_installing = surface;
    return true;
}

const char *BillboardRecoveryUI::GetResolution() {
    int w = gr_fb_width();
    int h = gr_fb_height();

    if (w == 1920 && h == 1080)
        return "1080p";
    if (w == 1280 && h == 720)
        return "720p";
    if (w == 640 && h == 480)
        return "480p";

    /* default to 720p */
    return "720p";
}

#ifdef BOARD_SUPPORTS_BILLBOARD
void BillboardRecoveryUI::SetZipArchive(ZipArchiveHandle *zip)
{
    if (zip == NULL) {
        billboard_frames = 0;
        return;
    }
    /* Try to extract the billboard resources */
    LoadBillboards(ExtractBillboards(zip));
}

int BillboardRecoveryUI::ExtractBillboards(ZipArchiveHandle *zip) {
    int i, fd = 0;
    char path[256];
    ZipEntry entry;
    ZipString entry_name;
    char *prefix = NULL;
    const char *sku = NULL;
    const char *resolution = GetResolution();

    /* create "/tmp/images" */
    mkdir("/tmp/images", 0755);

    prefix = find_prefix(zip, sku, resolution);
    if (prefix == NULL)
        return 0;

    /* extract billboard images */
    for (i = 0; i < MAX_BILLBOARD_IMAGES; i++) {
        snprintf(path, 255, "%s_%d.png", prefix, i);
        entry_name.name = (const uint8_t *) path;
        entry_name.name_length = (uint16_t) strlen(path);
        if (FindEntry(zip, entry_name, &entry)) {
                break;
        }

        snprintf(path, 255, "/tmp/images/billboard-%d.png", i);
        unlink(path);
        fd = creat(path, 0755);
        if (fd < 0) {
                ALOGE("Can't create %s\n", path);
                break;
        }
        ExtractEntryToFile(zip, &entry, fd);
        close(fd);
    }
    ALOGI("Extracted %d billboard images\n", i);
    free(prefix);

    if (i)
        return i;

    /* check local resource as well */
    for (i = 0; i < MAX_BILLBOARD_IMAGES; i++) {
        snprintf(path, 255, "/res/images/billboard-%d.png", i);
        fd = open(path, O_RDONLY);
        if (fd <= 0)
            break;
        close(fd);
    }
    ALOGI("Found %d billboard images in resource\n", i);
    return i;
}
#endif

int BillboardRecoveryUI::LoadBillboards(int frames) {
    GRSurface **surfaces = NULL;
    char filename[256];
    int result = 0;

    billboard_frames = frames;

    if (!frames) {
        ALOGE("Zero frames in LoadBillboards\n");
        billboards = surfaces;
        return 0;
    }

    surfaces = reinterpret_cast<GRSurface**>(malloc(frames * sizeof(GRSurface*)));
    if (surfaces == NULL)
        return -ENOMEM;

    billboard_showtime = reinterpret_cast<int *>(malloc(frames * sizeof(GRSurface*)));
    if (billboard_showtime == NULL)
	return -ENOMEM;

    for (int i = 0; i < frames; i++) {
        int showtime;
        snprintf(filename, 255, "billboard-%d", i);
        result = create_billboard_surface(filename, &locale_, &showtime, &surfaces[i]);
        if (result < 0)
            ALOGE("missing bitmap %s\n(Code %d)\n", filename, result);
        billboard_showtime[i] = showtime;
    }

    billboards = surfaces;
    return 0;
}

void BillboardRecoveryUI::LoadBitmap(const char* filename, GRSurface **surface) {
    char fn[256];
    snprintf(fn, 256, "%s_%s", filename, GetResolution());
    int result = create_billboard_surface(fn, &locale_, NULL, surface);
    if (result < 0) {
        ALOGE("missing bitmap %s\n(Code %d)\n", filename, result);
    }
}

#if (PLATFORM_IS_AFTER_M == 1)
void BillboardRecoveryUI::draw_background_locked() {
    if (currentIcon == INSTALLING_UPDATE) {
#else
void BillboardRecoveryUI::draw_background_locked(Icon icon) {
    if (icon == INSTALLING_UPDATE) {
#endif
        GRSurface* surface = billboard_installing;
        int x, y, w, h;

        if (billboards)
            surface = billboards[billboard_frame];

        w = gr_get_width(surface);
        h = gr_get_height(surface);
        x = (gr_fb_width() - w) / 2;
        y = (gr_fb_height() - h) / 2;
        gr_blit(surface, 0, 0, w, h, x, y);

        if (progressBarType != EMPTY) {
            w = gr_get_width(progressBarEmpty);
            h = gr_get_height(progressBarEmpty);
            x = (gr_fb_width() - w)/2;
            y = gr_fb_height() * 90 / 100;
            gr_blend(progressBarEmpty, 0, 0, w, h, x, y);
        }
        return;
    }
}

#if (PLATFORM_IS_AFTER_M == 1)
void BillboardRecoveryUI::draw_foreground_locked() {
#else
void BillboardRecoveryUI::draw_progress_locked() {
#endif
    if (currentIcon == INSTALLING_UPDATE) {
        if (progressBarType == EMPTY)
            return;
        GRSurface* surface = billboard_installing;
        int x, y, w, h;

        if (billboards)
            surface = billboards[billboard_frame];

        w = gr_get_width(surface);
        h = gr_get_height(surface);
        x = (gr_fb_width() - w) / 2;
        y = (gr_fb_height() - h) / 2;
        gr_blit(surface, 0, 0, w, h, x, y);

        if (progressBarType != EMPTY) {
            w = gr_get_width(progressBarEmpty);
            h = gr_get_height(progressBarEmpty);
            x = (gr_fb_width() - w)/2;
            y = gr_fb_height() * 90 / 100;
            gr_blend(progressBarEmpty, 0, 0, w, h, x, y);
        }
    }

    int bw = gr_get_width(progressBarEmpty);
    int bh = gr_get_height(progressBarEmpty);
    int fw = gr_get_width(progressBarFill);
    int fh = gr_get_height(progressBarFill);
    int bx = (gr_fb_width() - bw)/2;
    int by = gr_fb_height() * 90 / 100;

    float p = progressScopeStart + progress * progressScopeSize;
    int pos = (int) (p * fw);

    if (progressBarType == DETERMINATE && pos > 0) {
        int fx = bx + (bw - fw) / 2;
        int fy = by + (bh - fh) / 2;

        if (rtl_locale_)
            // Fill the progress bar from right to left.
            gr_blit(progressBarFill, fw-pos, 0, pos, fh, fx+fw-pos, fy);
        else
            // Fill the progress bar from left to right.
            gr_blit(progressBarFill, 0, 0, pos, fh, fx, fy);
    }
    return;
}

static double now() {
    struct timeval tv;
    gettimeofday(&tv, nullptr);
    return tv.tv_sec + tv.tv_usec / 1000000.0;
}

void BillboardRecoveryUI::ProgressThreadLoop() {
#if (PLATFORM_IS_AFTER_O_MR0 == 1)
    double interval = 1.0 / kAnimationFps;
#else
    double interval = 1.0 / animation_fps;
#endif
    double billboard_last_shown = -100000;
    while (true) {
        double start = now();
        pthread_mutex_lock(&updateMutex);

        int redraw = 0;

        // move the progress bar forward on timed intervals, if configured
        int duration = progressScopeDuration;
        if (progressBarType == DETERMINATE && duration > 0) {
            double elapsed = now() - progressScopeTime;
            float p = 1.0 * elapsed / duration;
            if (p > 1.0) p = 1.0;
            if (p > progress) {
                progress = p;
                redraw = 1;
            }
        }

        // update the billboard frames every specified interval
        if (currentIcon == INSTALLING_UPDATE &&
            billboard_frames > 0 && !show_text) {
            if (start - billboard_last_shown > billboard_showtime[billboard_frame]) {
                billboard_frame = (billboard_frame + 1) % billboard_frames;
                billboard_last_shown = start;
                redraw = 2;
            }
        }

        if (redraw == 2)
            update_screen_locked();
        else if (redraw == 1)
            update_progress_locked();

        pthread_mutex_unlock(&updateMutex);
        double end = now();
        // minimum of 20ms delay between frames
        double delay = interval - (end-start);
        if (delay < 0.02) delay = 0.02;
        usleep((long)(delay * 1000000));
    }
}
