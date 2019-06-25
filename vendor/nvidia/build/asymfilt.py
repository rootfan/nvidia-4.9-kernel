#!/usr/bin/env python
#
# Copyright (c) 2011-2014 NVIDIA Corporation.  All Rights Reserved.
#
# NVIDIA Corporation and its licensors retain all intellectual property
# and proprietary rights in and to this software, related documentation
# and any modifications thereto.  Any use, reproduction, disclosure or
# distribution of this software and related documentation without an express
# license agreement from NVIDIA Corporation is strictly prohibited.
#

import os
import re
import subprocess
import sys
import bisect

import logging
# Uncomment to enable logging to stderr.
#logging.basicConfig(level=logging.DEBUG)

android_product_out = os.environ['ANDROID_PRODUCT_OUT']
symbols_dir = os.path.join(android_product_out, 'symbols')
toolchain_prefix_32bit = 'arm-linux-androideabi-'
toolchain_prefix_64bit = 'aarch64-linux-android-'

class Mode:
    default = 0
    nvos = 1

def stdout_of_cmd(*args):
    return subprocess.Popen(args,
                            stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE).communicate()[0]

class IntervalMap:
    def __init__(self):
        self.ranges = []
    def __setitem__(self, _slice, v):
        self.ranges.append((_slice.start, _slice.stop, v))
    def finalize(self):
        self.starts, self.stops, self.values = zip(*sorted(self.ranges))
    def __getitem__(self, k):
        pos = bisect.bisect_right(self.starts, k)
        if pos == 0:
            return None
        pos = pos - 1
        if k >= self.stops[pos]:
            return None
        return self.values[pos]

def add_map(im, line):
    try:
        parts = line.split()
        if len(parts) >= 6 and parts[1][2] == 'x' and parts[5][0] == '/':
            sep = parts[0].find('-')
            start = int(parts[0][:sep], 16)
            end = int(parts[0][sep+1:], 16)
            module = parts[5]
            im[start:end] = (module, start)
    except:
       pass

rexp_class = re.compile('\s*Class:\s*ELF(\d+)')
cache_class = dict()
def is_64bit(symfile):
    if not symfile in cache_class:
        elf_header = stdout_of_cmd(toolchain_prefix_32bit + 'readelf', '-h', symfile)
        elf_header = elf_header.splitlines()
        for line in elf_header:
            match = rexp_class.match(line)
            if match:
                cache_class[symfile] = (match.group(1) == '64')
                break

    assert symfile in cache_class
    return cache_class[symfile]

cppRE = re.compile(r'(.*) \([+\w]*\)')
def addr2line(symbols_dir, module, offset):
    try:
        m = cppRE.match(module)
        if m:
          module = m.group(1)
        module_dir, module_name = os.path.split(module)
        symfile = symbols_dir + module
        assert os.path.isfile(symfile)

        if is_64bit(symfile):
            toolchain_prefix = toolchain_prefix_64bit
        else:
            toolchain_prefix = toolchain_prefix_32bit

        # -C for demangling, -f for functions
        stuff = stdout_of_cmd(toolchain_prefix + 'addr2line', '-C', '-f', '-e',
                              symfile, hex(offset))

        func, line = stuff.splitlines()
        try:
            line = line[line.index('/mobile/')+8:]
        except:
            pass

        return module_name + ':' + func + '():' + line

    except:
        return '%s + %s (no symbols found)' % (module, hex(offset))


def android_lookup(line, header, info, rexp):
    match = rexp.match(info)
    if not match:
        return line

    beginning, addr, module = match.groups()
    addr = int(addr, 16)
    # want the branch, not the return address
    if addr:
        addr -= 1

    logging.debug( 'Looking up ' + module + ' in addr ' + str(addr))
    lookup = addr2line(symbols_dir, module, addr)

    return header + beginning + lookup


def main():

    ####################################################
    # regexp that detects ADB headers
    # D/libEGL  ( 1806): loaded /vendor/lib/egl/libEGL_tegra.so
    # <--ADB HEADER-G1-><----------------- INFO G3----------------------->
    # Pid will be in group 2
    rexp_adb = re.compile('(./.*\(\s*(\d+)\):\s?)(.*)')

    ####################################################
    # regexp that detects NvOs headers and similar tags
    # (for callstacks printed by the NvOs resource tracker).
    #          [NVOS] Leaked 2 resources!
    # GROUPS:  <- 1 -><------- 2 -------->
    rexp_tag = re.compile('(\\[\w*?\\]\s?)(.*)') #\[w*?\]

    ####################################################
    # regexps with _start and _end define where interesting
    # stuff begins and ends. Applied to INFO part.

    ## Default mode
    # Android callstack
    #           #01  pc 0014a784  /system/lib/libwebcore.so (__libc_init+50)
    # GROUPS:  <-- 1 --><- 2 -->  <---------- 3 ----------> <------ 4 ----->
    rexp_android = re.compile('([^#]*#\d+\s+\w\w\s+)([\w]+)\s+(/[^ ]*)(?: \(.+\))?$')

    ## NvOs callstack mode
    rexp_nvos_start = re.compile('Callstack:')
    rexp_nvos_end = re.compile('^$')

    if not os.path.exists(symbols_dir):
        print '$ANDROID_PRODUCT_OUT/symbols does not exist ('+ symbols_dir + ')'
        return

    pstate = {}
    mode = Mode.default

    while 1:

        line = sys.stdin.readline()
        if not line:
            break
        line = line.rstrip()

        # Detect whether we have a header from ADB
        adbmatch = rexp_adb.match(line)
        if adbmatch:
            header, pid, info = adbmatch.groups()
        else:
            header, pid, info = '', None, line

        # If we detect a [] tag, move it to the header.
        tagmatch = rexp_tag.match(info)
        if tagmatch:
            header += tagmatch.group(1)
            info = tagmatch.group(2)

        ### Simple state machine

        ########################
        if mode == Mode.default:
            # Detect if we're on an Android callstack line
            if rexp_android.match(info):
                logging.debug( 'Android callstack mode - ' + info)
                line = android_lookup(line, header, info, rexp_android)
            else:
                logging.debug( 'Default mode - ' + info)

                # Try searching for keywords that start the NvOs mode
                if rexp_nvos_start.match(info):
                    mode = Mode.nvos
                    im = None

        ##########################
        elif mode == Mode.nvos:
            logging.debug( 'NvOs callstack mode - ' + info )

            # If we reach the empty line after stack dump.
            if rexp_nvos_end.match(info):
                mode = Mode.default
                continue

            try:
                try:
                    im, pm = pstate[pid]
                except:
                    im, pm = None, False

                if info.startswith('BeginProcMap'):
                    im = IntervalMap()
                    pm = True
                    line = None
                elif info.startswith('EndProcMap'):
                    im.finalize()
                    pm = False
                    line = None
                elif pm:
                    add_map(im, info)
                    line = None
                elif im is not None:
                    try:
                        pos = info.index('0x')+2
                        addr = int(info[pos:], 16)
                        module, start = im[addr]
                        if addr > start:
                            addr = addr - 1
                        lookup = addr2line(symbols_dir, module, addr - start)
                        line = header + lookup
                    except:
                        line = header + hex(addr) + " (no module found)"

                pstate[pid] = (im, pm)
            except:
                pass


        ## Print the line.
        if line is not None:
            print line
            sys.stdout.flush()

if __name__=='__main__':
   main()
