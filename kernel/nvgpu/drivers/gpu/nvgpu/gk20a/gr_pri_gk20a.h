/*
 * GK20A Graphics Context Pri Register Addressing
 *
 * Copyright (c) 2014-2018, NVIDIA CORPORATION.  All rights reserved.
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
#ifndef GR_PRI_GK20A_H
#define GR_PRI_GK20A_H

/*
 * These convenience macros are generally for use in the management/modificaiton
 * of the context state store for gr/compute contexts.
 */

#include <nvgpu/hw/gk20a/hw_ltc_gk20a.h>

/*
 * GPC pri addressing
 */
static inline u32 pri_gpccs_addr_width(void)
{
	return 15; /*from where?*/
}
static inline u32 pri_gpccs_addr_mask(u32 addr)
{
	return addr & ((1 << pri_gpccs_addr_width()) - 1);
}
static inline u32 pri_gpc_addr(struct gk20a *g, u32 addr, u32 gpc)
{
	u32 gpc_base = nvgpu_get_litter_value(g, GPU_LIT_GPC_BASE);
	u32 gpc_stride = nvgpu_get_litter_value(g, GPU_LIT_GPC_STRIDE);
	return gpc_base + (gpc * gpc_stride) + addr;
}
static inline bool pri_is_gpc_addr_shared(struct gk20a *g, u32 addr)
{
	u32 gpc_shared_base = nvgpu_get_litter_value(g, GPU_LIT_GPC_SHARED_BASE);
	u32 gpc_stride = nvgpu_get_litter_value(g, GPU_LIT_GPC_STRIDE);
	return (addr >= gpc_shared_base) &&
		(addr < gpc_shared_base + gpc_stride);
}
static inline bool pri_is_gpc_addr(struct gk20a *g, u32 addr)
{
	u32 gpc_base = nvgpu_get_litter_value(g, GPU_LIT_GPC_BASE);
	u32 gpc_stride = nvgpu_get_litter_value(g, GPU_LIT_GPC_STRIDE);
	u32 num_gpcs = nvgpu_get_litter_value(g, GPU_LIT_NUM_GPCS);
	return	((addr >= gpc_base) &&
		 (addr < gpc_base + num_gpcs * gpc_stride)) ||
		pri_is_gpc_addr_shared(g, addr);
}
static inline u32 pri_get_gpc_num(struct gk20a *g, u32 addr)
{
	u32 i, start;
	u32 num_gpcs = nvgpu_get_litter_value(g, GPU_LIT_NUM_GPCS);
	u32 gpc_base = nvgpu_get_litter_value(g, GPU_LIT_GPC_BASE);
	u32 gpc_stride = nvgpu_get_litter_value(g, GPU_LIT_GPC_STRIDE);
	for (i = 0; i < num_gpcs; i++) {
		start = gpc_base + (i * gpc_stride);
		if ((addr >= start) && (addr < (start + gpc_stride)))
			return i;
	}
	return 0;
}

/*
 * PPC pri addressing
 */
static inline bool pri_is_ppc_addr_shared(struct gk20a *g, u32 addr)
{
	u32 ppc_in_gpc_shared_base = nvgpu_get_litter_value(g,
						GPU_LIT_PPC_IN_GPC_SHARED_BASE);
	u32 ppc_in_gpc_stride = nvgpu_get_litter_value(g,
						GPU_LIT_PPC_IN_GPC_STRIDE);

	return ((addr >= ppc_in_gpc_shared_base) &&
		(addr < (ppc_in_gpc_shared_base + ppc_in_gpc_stride)));
}

static inline bool pri_is_ppc_addr(struct gk20a *g, u32 addr)
{
	u32 ppc_in_gpc_base = nvgpu_get_litter_value(g,
						GPU_LIT_PPC_IN_GPC_BASE);
	u32 num_pes_per_gpc = nvgpu_get_litter_value(g,
						GPU_LIT_NUM_PES_PER_GPC);
	u32 ppc_in_gpc_stride = nvgpu_get_litter_value(g,
						GPU_LIT_PPC_IN_GPC_STRIDE);

	return ((addr >= ppc_in_gpc_base) &&
		(addr < ppc_in_gpc_base + num_pes_per_gpc * ppc_in_gpc_stride))
		|| pri_is_ppc_addr_shared(g, addr);
}

/*
 * TPC pri addressing
 */
static inline u32 pri_tpccs_addr_width(void)
{
	return 11; /* from where? */
}
static inline u32 pri_tpccs_addr_mask(u32 addr)
{
	return addr & ((1 << pri_tpccs_addr_width()) - 1);
}
static inline u32 pri_fbpa_addr_mask(struct gk20a *g, u32 addr)
{
	return addr & (nvgpu_get_litter_value(g, GPU_LIT_FBPA_STRIDE) - 1);
}
static inline u32 pri_tpc_addr(struct gk20a *g, u32 addr, u32 gpc, u32 tpc)
{
	u32 gpc_base = nvgpu_get_litter_value(g, GPU_LIT_GPC_BASE);
	u32 gpc_stride = nvgpu_get_litter_value(g, GPU_LIT_GPC_STRIDE);
	u32 tpc_in_gpc_base = nvgpu_get_litter_value(g, GPU_LIT_TPC_IN_GPC_BASE);
	u32 tpc_in_gpc_stride = nvgpu_get_litter_value(g, GPU_LIT_TPC_IN_GPC_STRIDE);
	return gpc_base + (gpc * gpc_stride) +
		tpc_in_gpc_base + (tpc * tpc_in_gpc_stride) +
		addr;
}
static inline bool pri_is_tpc_addr_shared(struct gk20a *g, u32 addr)
{
	u32 tpc_in_gpc_stride = nvgpu_get_litter_value(g, GPU_LIT_TPC_IN_GPC_STRIDE);
	u32 tpc_in_gpc_shared_base = nvgpu_get_litter_value(g, GPU_LIT_TPC_IN_GPC_SHARED_BASE);
	return (addr >= tpc_in_gpc_shared_base) &&
		(addr < (tpc_in_gpc_shared_base +
			 tpc_in_gpc_stride));
}
static inline u32 pri_fbpa_addr(struct gk20a *g, u32 addr, u32 fbpa)
{
	return (nvgpu_get_litter_value(g, GPU_LIT_FBPA_BASE) + addr +
			(fbpa * nvgpu_get_litter_value(g, GPU_LIT_FBPA_STRIDE)));
}
static inline bool pri_is_fbpa_addr_shared(struct gk20a *g, u32 addr)
{
	u32 fbpa_shared_base = nvgpu_get_litter_value(g, GPU_LIT_FBPA_SHARED_BASE);
	u32 fbpa_stride = nvgpu_get_litter_value(g, GPU_LIT_FBPA_STRIDE);
	return ((addr >= fbpa_shared_base) &&
		(addr < (fbpa_shared_base + fbpa_stride)));
}
static inline bool pri_is_fbpa_addr(struct gk20a *g, u32 addr)
{
	u32 fbpa_base = nvgpu_get_litter_value(g, GPU_LIT_FBPA_BASE);
	u32 fbpa_stride = nvgpu_get_litter_value(g, GPU_LIT_FBPA_STRIDE);
	u32 num_fbpas = nvgpu_get_litter_value(g, GPU_LIT_NUM_FBPAS);
	return (((addr >= fbpa_base) &&
		(addr < (fbpa_base + num_fbpas * fbpa_stride)))
		|| pri_is_fbpa_addr_shared(g, addr));
}
/*
 * BE pri addressing
 */
static inline u32 pri_becs_addr_width(void)
{
	return 10;/* from where? */
}
static inline u32 pri_becs_addr_mask(u32 addr)
{
	return addr & ((1 << pri_becs_addr_width()) - 1);
}
static inline bool pri_is_be_addr_shared(struct gk20a *g, u32 addr)
{
	u32 rop_shared_base = nvgpu_get_litter_value(g, GPU_LIT_ROP_SHARED_BASE);
	u32 rop_stride = nvgpu_get_litter_value(g, GPU_LIT_ROP_STRIDE);
	return (addr >= rop_shared_base) &&
		(addr < rop_shared_base + rop_stride);
}
static inline u32 pri_be_shared_addr(struct gk20a *g, u32 addr)
{
	u32 rop_shared_base = nvgpu_get_litter_value(g, GPU_LIT_ROP_SHARED_BASE);
	return rop_shared_base + pri_becs_addr_mask(addr);
}
static inline bool pri_is_be_addr(struct gk20a *g, u32 addr)
{
	u32 rop_base = nvgpu_get_litter_value(g, GPU_LIT_ROP_BASE);
	u32 rop_stride = nvgpu_get_litter_value(g, GPU_LIT_ROP_STRIDE);
	return	((addr >= rop_base) &&
		 (addr < rop_base + g->ltc_count * rop_stride)) ||
		pri_is_be_addr_shared(g, addr);
}

static inline u32 pri_get_be_num(struct gk20a *g, u32 addr)
{
	u32 i, start;
	u32 num_fbps = nvgpu_get_litter_value(g, GPU_LIT_NUM_FBPS);
	u32 rop_base = nvgpu_get_litter_value(g, GPU_LIT_ROP_BASE);
	u32 rop_stride = nvgpu_get_litter_value(g, GPU_LIT_ROP_STRIDE);
	for (i = 0; i < num_fbps; i++) {
		start = rop_base + (i * rop_stride);
		if ((addr >= start) && (addr < (start + rop_stride)))
			return i;
	}
	return 0;
}

/*
 * PPC pri addressing
 */
static inline u32 pri_ppccs_addr_width(void)
{
	return 9; /* from where? */
}
static inline u32 pri_ppccs_addr_mask(u32 addr)
{
	return addr & ((1 << pri_ppccs_addr_width()) - 1);
}
static inline u32 pri_ppc_addr(struct gk20a *g, u32 addr, u32 gpc, u32 ppc)
{
	u32 gpc_base = nvgpu_get_litter_value(g, GPU_LIT_GPC_BASE);
	u32 gpc_stride = nvgpu_get_litter_value(g, GPU_LIT_GPC_STRIDE);
	u32 ppc_in_gpc_base = nvgpu_get_litter_value(g, GPU_LIT_PPC_IN_GPC_BASE);
	u32 ppc_in_gpc_stride = nvgpu_get_litter_value(g, GPU_LIT_PPC_IN_GPC_STRIDE);
	return gpc_base + (gpc * gpc_stride) +
		ppc_in_gpc_base + (ppc * ppc_in_gpc_stride) + addr;
}

/*
 * LTC pri addressing
 */
static inline bool pri_is_ltc_addr(u32 addr)
{
	return ((addr >= ltc_pltcg_base_v()) && (addr < ltc_pltcg_extent_v()));
}

enum ctxsw_addr_type {
	CTXSW_ADDR_TYPE_SYS  = 0,
	CTXSW_ADDR_TYPE_GPC  = 1,
	CTXSW_ADDR_TYPE_TPC  = 2,
	CTXSW_ADDR_TYPE_BE   = 3,
	CTXSW_ADDR_TYPE_PPC  = 4,
	CTXSW_ADDR_TYPE_LTCS = 5,
	CTXSW_ADDR_TYPE_FBPA = 6,
	CTXSW_ADDR_TYPE_EGPC = 7,
	CTXSW_ADDR_TYPE_ETPC = 8,
	CTXSW_ADDR_TYPE_ROP  = 9,
	CTXSW_ADDR_TYPE_FBP  = 10,
};

#define PRI_BROADCAST_FLAGS_NONE		0
#define PRI_BROADCAST_FLAGS_GPC			BIT(0)
#define PRI_BROADCAST_FLAGS_TPC			BIT(1)
#define PRI_BROADCAST_FLAGS_BE			BIT(2)
#define PRI_BROADCAST_FLAGS_PPC			BIT(3)
#define PRI_BROADCAST_FLAGS_LTCS		BIT(4)
#define PRI_BROADCAST_FLAGS_LTSS		BIT(5)
#define PRI_BROADCAST_FLAGS_FBPA		BIT(6)
#define PRI_BROADCAST_FLAGS_EGPC		BIT(7)
#define PRI_BROADCAST_FLAGS_ETPC		BIT(8)
#define PRI_BROADCAST_FLAGS_PMMGPC		BIT(9)
#define PRI_BROADCAST_FLAGS_PMM_GPCS		BIT(10)
#define PRI_BROADCAST_FLAGS_PMM_GPCGS_GPCTPCA	BIT(11)
#define PRI_BROADCAST_FLAGS_PMM_GPCGS_GPCTPCB	BIT(12)
#define PRI_BROADCAST_FLAGS_PMMFBP		BIT(13)
#define PRI_BROADCAST_FLAGS_PMM_FBPS		BIT(14)
#define PRI_BROADCAST_FLAGS_PMM_FBPGS_LTC	BIT(15)
#define PRI_BROADCAST_FLAGS_PMM_FBPGS_ROP	BIT(16)

#endif /* GR_PRI_GK20A_H */
