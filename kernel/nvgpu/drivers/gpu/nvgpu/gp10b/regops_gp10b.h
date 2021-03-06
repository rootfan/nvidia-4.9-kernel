/*
 *
 * Tegra GP10B GPU Debugger Driver Register Ops
 *
 * Copyright (c) 2015-2017, NVIDIA CORPORATION. All rights reserved.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
 * THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 */
#ifndef __REGOPS_GP10B_H_
#define __REGOPS_GP10B_H_

struct dbg_session_gk20a;

const struct regop_offset_range *gp10b_get_global_whitelist_ranges(void);
int gp10b_get_global_whitelist_ranges_count(void);
const struct regop_offset_range *gp10b_get_context_whitelist_ranges(void);
int gp10b_get_context_whitelist_ranges_count(void);
const u32 *gp10b_get_runcontrol_whitelist(void);
int gp10b_get_runcontrol_whitelist_count(void);
const struct regop_offset_range *gp10b_get_runcontrol_whitelist_ranges(void);
int gp10b_get_runcontrol_whitelist_ranges_count(void);
const u32 *gp10b_get_qctl_whitelist(void);
int gp10b_get_qctl_whitelist_count(void);
const struct regop_offset_range *gp10b_get_qctl_whitelist_ranges(void);
int gp10b_get_qctl_whitelist_ranges_count(void);
int gp10b_apply_smpc_war(struct dbg_session_gk20a *dbg_s);

#endif /* __REGOPS_GP10B_H_ */
