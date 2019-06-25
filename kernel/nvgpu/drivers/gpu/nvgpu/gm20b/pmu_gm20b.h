/*
 * GM20B PMU
 *
 * Copyright (c) 2014-2017, NVIDIA CORPORATION.  All rights reserved.
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

#ifndef __PMU_GM20B_H_
#define __PMU_GM20B_H_

struct gk20a;

int gm20b_load_falcon_ucode(struct gk20a *g, u32 falconidmask);
int gm20b_pmu_setup_elpg(struct gk20a *g);
void pmu_dump_security_fuses_gm20b(struct gk20a *g);
void gm20b_pmu_load_lsf(struct gk20a *g, u32 falcon_id, u32 flags);
int gm20b_pmu_init_acr(struct gk20a *g);
void gm20b_write_dmatrfbase(struct gk20a *g, u32 addr);

#endif /*__PMU_GM20B_H_*/
