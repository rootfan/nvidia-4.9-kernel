#
# Copyright (c) 2016, NVIDIA Corporation.  All Rights Reserved.
#
# NVIDIA Corporation and its licensors retain all intellectual property
# and proprietary rights in and to this software, related documentation
# and any modifications thereto.  Any use, reproduction, disclosure or
# distribution of this software and related documentation without an express
# license agreement from NVIDIA Corporation is strictly prohibited.
#
#!/usr/bin/env python

import sys
import os
import re
import subprocess

# no more than 100 images
MAX_IMAGES = 100

RESOLUTIONS = {
    '1080p' : '1920x1080!',
    '720p'  : '1280x720!',
    '480p'  : '640x480!',
}

SHOWTIMES = [10] * MAX_IMAGES

def convert_resolution(root, dst_file, src_file, target_res):
    subprocess.call(["convert", os.path.join(root, src_file),
                    "-resize", RESOLUTIONS[target_res],
                    os.path.join(root, dst_file)])
    return dst_file

def convert_composite(root, dst_file, src_list, kw_list):
    cmd = ["convert"] + [ f for f in src_list ] + ['-append']
    for i in xrange(0, len(kw_list)):
        p = os.path.join(root, 'tmp.kw%.3d.txt' % i)
        with open(p, 'wb') as f:
            k, v = kw_list[i]
            f.write('tEXt:%s\0%s' % (k, str(v)))
        profile = 'PNG-chunk-b%.3d:%s' % (i, p)
        cmd += ['-set', 'profile', profile]
    cmd += [dst_file]
    subprocess.call(cmd)
    #print ' '.join(cmd)
    return dst_file

def generate_billboard_images(root):

    root = os.path.abspath(root)
    # change to root
    os.chdir(root)

    idx_list = set()
    images = {}
    locales = set(['base'])

    r_png_name = re.compile(r'image_(\w+)_(\d+)_(\w+).png')
    for f in os.listdir(root):
        m = r_png_name.match(f)
        if m:
            res, idx, _locales = m.groups()
            idx = int(idx)
            idx_list.add(idx)
            locales.add(_locales)
            images['%s_%d_%s' % (res, idx, _locales)] = f

    idx_list = sorted(idx_list)
    # check index
    if len(idx_list) > MAX_IMAGES:
        sys.exit("Too many images (%d > %d)" % (len(idx_list), MAX_IMAGES))

    # check the completeness of the 1080p version
    for idx in idx_list:
        for loc in locales:
            k = '1080p_%d_%s' % (idx, loc)
            if not images.has_key(k):
                sys.exit("Missing image_%s.png" % k)

    # print basic information
    print("Found %d images, locales=%s" % (len(idx_list), sorted(locales)))

    # try generating the missing images for 720p and 480p
    # from the 1080p version
    for res in ['720p', '480p']:
        for idx in idx_list:
            for loc in locales:
                k = '%s_%d_%s' % (res, idx, loc)
                if images.has_key(k):
                    continue
                s = '1080p_%d_%s' % (idx, loc)
                if not images.has_key(s):
                    sys.exit("Missing image_%s.png" % s)

                print("Missing %-20s: generating from image_%s" % (k, s))
                images[k] = convert_resolution(root,
                        'image_%s.png' % k, 'image_%s.png' % s, res)

    # try composite the images of base and different locales
    locales.remove('base')
    for res in ['1080p', '720p', '480p']:
        for dst in xrange(0, len(idx_list)):
            keyword_list = []
            image_list = [ 'image_%s_%d_base.png' % (res, idx_list[dst]) ]
            for loc in locales:
                k = '%s_%d_%s' % (res, idx_list[dst], loc)
                keyword_list += [(l, len(image_list)) for l in loc.split(',')]
                image_list.append(images[k])

            keyword_list += [
                ('frames', len(image_list)),
                ('showtime', SHOWTIMES[dst]),
            ]

            keyword_list = sorted(keyword_list, key=lambda x: x[0])

            f = convert_composite(root,
                        'image_%s_%d.png' % (res, dst),
                        image_list, keyword_list)
            print("Generated %s from %s:" % (f, image_list))
            for k, v in keyword_list:
                print("    %20s : %s" % (k, v))

if __name__ == "__main__":
    p = '.' if len(sys.argv) < 2 else sys.argv[1]
    generate_billboard_images(p)

