/*
 * GK20A Graphics Context for Simulation
 *
 * Copyright (c) 2011-2018, NVIDIA CORPORATION.  All rights reserved.
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

#include "gk20a.h"
#include <nvgpu/sim.h>
#include "gr_ctx_gk20a.h"

#include <nvgpu/log.h>

int gr_gk20a_init_ctx_vars_sim(struct gk20a *g, struct gr_gk20a *gr)
{
	int err = 0;
	u32 i, temp;

	nvgpu_log(g, gpu_dbg_fn | gpu_dbg_info,
		   "querying grctx info from chiplib");

	g->gr.ctx_vars.dynamic = true;
	g->gr.netlist = GR_NETLIST_DYNAMIC;

	if(!g->sim->esc_readl) {
		nvgpu_err(g, "Invalid pointer to query function.");
		goto fail;
	}

	/* query sizes and counts */
	g->sim->esc_readl(g, "GRCTX_UCODE_INST_FECS_COUNT", 0,
			    &g->gr.ctx_vars.ucode.fecs.inst.count);
	g->sim->esc_readl(g, "GRCTX_UCODE_DATA_FECS_COUNT", 0,
			    &g->gr.ctx_vars.ucode.fecs.data.count);
	g->sim->esc_readl(g, "GRCTX_UCODE_INST_GPCCS_COUNT", 0,
			    &g->gr.ctx_vars.ucode.gpccs.inst.count);
	g->sim->esc_readl(g, "GRCTX_UCODE_DATA_GPCCS_COUNT", 0,
			    &g->gr.ctx_vars.ucode.gpccs.data.count);
	g->sim->esc_readl(g, "GRCTX_ALL_CTX_TOTAL_WORDS", 0, &temp);
	g->gr.ctx_vars.buffer_size = temp << 2;
	g->sim->esc_readl(g, "GRCTX_SW_BUNDLE_INIT_SIZE", 0,
			    &g->gr.ctx_vars.sw_bundle_init.count);
	g->sim->esc_readl(g, "GRCTX_SW_METHOD_INIT_SIZE", 0,
			    &g->gr.ctx_vars.sw_method_init.count);
	g->sim->esc_readl(g, "GRCTX_SW_CTX_LOAD_SIZE", 0,
			    &g->gr.ctx_vars.sw_ctx_load.count);
	g->sim->esc_readl(g, "GRCTX_SW_VEID_BUNDLE_INIT_SIZE", 0,
			    &g->gr.ctx_vars.sw_veid_bundle_init.count);

	g->sim->esc_readl(g, "GRCTX_NONCTXSW_REG_SIZE", 0,
			    &g->gr.ctx_vars.sw_non_ctx_load.count);
	g->sim->esc_readl(g, "GRCTX_REG_LIST_SYS_COUNT", 0,
			    &g->gr.ctx_vars.ctxsw_regs.sys.count);
	g->sim->esc_readl(g, "GRCTX_REG_LIST_GPC_COUNT", 0,
			    &g->gr.ctx_vars.ctxsw_regs.gpc.count);
	g->sim->esc_readl(g, "GRCTX_REG_LIST_TPC_COUNT", 0,
			    &g->gr.ctx_vars.ctxsw_regs.tpc.count);
	g->sim->esc_readl(g, "GRCTX_REG_LIST_ZCULL_GPC_COUNT", 0,
			    &g->gr.ctx_vars.ctxsw_regs.zcull_gpc.count);
	g->sim->esc_readl(g, "GRCTX_REG_LIST_PM_SYS_COUNT", 0,
			    &g->gr.ctx_vars.ctxsw_regs.pm_sys.count);
	g->sim->esc_readl(g, "GRCTX_REG_LIST_PM_GPC_COUNT", 0,
			    &g->gr.ctx_vars.ctxsw_regs.pm_gpc.count);
	g->sim->esc_readl(g, "GRCTX_REG_LIST_PM_TPC_COUNT", 0,
			    &g->gr.ctx_vars.ctxsw_regs.pm_tpc.count);
	g->sim->esc_readl(g, "GRCTX_REG_LIST_PPC_COUNT", 0,
			    &g->gr.ctx_vars.ctxsw_regs.ppc.count);
	g->sim->esc_readl(g, "GRCTX_REG_LIST_ETPC_COUNT", 0,
			    &g->gr.ctx_vars.ctxsw_regs.etpc.count);
	g->sim->esc_readl(g, "GRCTX_REG_LIST_PPC_COUNT", 0,
			    &g->gr.ctx_vars.ctxsw_regs.ppc.count);

	err |= !alloc_u32_list_gk20a(g, &g->gr.ctx_vars.ucode.fecs.inst);
	err |= !alloc_u32_list_gk20a(g, &g->gr.ctx_vars.ucode.fecs.data);
	err |= !alloc_u32_list_gk20a(g, &g->gr.ctx_vars.ucode.gpccs.inst);
	err |= !alloc_u32_list_gk20a(g, &g->gr.ctx_vars.ucode.gpccs.data);
	err |= !alloc_av_list_gk20a(g, &g->gr.ctx_vars.sw_bundle_init);
	err |= !alloc_av_list_gk20a(g, &g->gr.ctx_vars.sw_method_init);
	err |= !alloc_aiv_list_gk20a(g, &g->gr.ctx_vars.sw_ctx_load);
	err |= !alloc_av_list_gk20a(g, &g->gr.ctx_vars.sw_non_ctx_load);
	err |= !alloc_av_list_gk20a(g, &g->gr.ctx_vars.sw_veid_bundle_init);
	err |= !alloc_aiv_list_gk20a(g, &g->gr.ctx_vars.ctxsw_regs.sys);
	err |= !alloc_aiv_list_gk20a(g, &g->gr.ctx_vars.ctxsw_regs.gpc);
	err |= !alloc_aiv_list_gk20a(g, &g->gr.ctx_vars.ctxsw_regs.tpc);
	err |= !alloc_aiv_list_gk20a(g, &g->gr.ctx_vars.ctxsw_regs.zcull_gpc);
	err |= !alloc_aiv_list_gk20a(g, &g->gr.ctx_vars.ctxsw_regs.ppc);
	err |= !alloc_aiv_list_gk20a(g, &g->gr.ctx_vars.ctxsw_regs.pm_sys);
	err |= !alloc_aiv_list_gk20a(g, &g->gr.ctx_vars.ctxsw_regs.pm_gpc);
	err |= !alloc_aiv_list_gk20a(g, &g->gr.ctx_vars.ctxsw_regs.pm_tpc);
	err |= !alloc_aiv_list_gk20a(g, &g->gr.ctx_vars.ctxsw_regs.etpc);

	if (err)
		goto fail;

	for (i = 0; i < g->gr.ctx_vars.ucode.fecs.inst.count; i++)
		g->sim->esc_readl(g, "GRCTX_UCODE_INST_FECS",
				    i, &g->gr.ctx_vars.ucode.fecs.inst.l[i]);

	for (i = 0; i < g->gr.ctx_vars.ucode.fecs.data.count; i++)
		g->sim->esc_readl(g, "GRCTX_UCODE_DATA_FECS",
				    i, &g->gr.ctx_vars.ucode.fecs.data.l[i]);

	for (i = 0; i < g->gr.ctx_vars.ucode.gpccs.inst.count; i++)
		g->sim->esc_readl(g, "GRCTX_UCODE_INST_GPCCS",
				    i, &g->gr.ctx_vars.ucode.gpccs.inst.l[i]);

	for (i = 0; i < g->gr.ctx_vars.ucode.gpccs.data.count; i++)
		g->sim->esc_readl(g, "GRCTX_UCODE_DATA_GPCCS",
				    i, &g->gr.ctx_vars.ucode.gpccs.data.l[i]);

	for (i = 0; i < g->gr.ctx_vars.sw_bundle_init.count; i++) {
		struct av_gk20a *l = g->gr.ctx_vars.sw_bundle_init.l;
		g->sim->esc_readl(g, "GRCTX_SW_BUNDLE_INIT:ADDR",
				    i, &l[i].addr);
		g->sim->esc_readl(g, "GRCTX_SW_BUNDLE_INIT:VALUE",
				    i, &l[i].value);
	}

	for (i = 0; i < g->gr.ctx_vars.sw_method_init.count; i++) {
		struct av_gk20a *l = g->gr.ctx_vars.sw_method_init.l;
		g->sim->esc_readl(g, "GRCTX_SW_METHOD_INIT:ADDR",
				    i, &l[i].addr);
		g->sim->esc_readl(g, "GRCTX_SW_METHOD_INIT:VALUE",
				    i, &l[i].value);
	}

	for (i = 0; i < g->gr.ctx_vars.sw_ctx_load.count; i++) {
		struct aiv_gk20a *l = g->gr.ctx_vars.sw_ctx_load.l;
		g->sim->esc_readl(g, "GRCTX_SW_CTX_LOAD:ADDR",
				    i, &l[i].addr);
		g->sim->esc_readl(g, "GRCTX_SW_CTX_LOAD:INDEX",
				    i, &l[i].index);
		g->sim->esc_readl(g, "GRCTX_SW_CTX_LOAD:VALUE",
				    i, &l[i].value);
	}

	for (i = 0; i < g->gr.ctx_vars.sw_non_ctx_load.count; i++) {
		struct av_gk20a *l = g->gr.ctx_vars.sw_non_ctx_load.l;
		g->sim->esc_readl(g, "GRCTX_NONCTXSW_REG:REG",
				    i, &l[i].addr);
		g->sim->esc_readl(g, "GRCTX_NONCTXSW_REG:VALUE",
				    i, &l[i].value);
	}

	for (i = 0; i < g->gr.ctx_vars.sw_veid_bundle_init.count; i++) {
		struct av_gk20a *l = g->gr.ctx_vars.sw_veid_bundle_init.l;

		g->sim->esc_readl(g, "GRCTX_SW_VEID_BUNDLE_INIT:ADDR",
				    i, &l[i].addr);
		g->sim->esc_readl(g, "GRCTX_SW_VEID_BUNDLE_INIT:VALUE",
				    i, &l[i].value);
	}

	for (i = 0; i < g->gr.ctx_vars.ctxsw_regs.sys.count; i++) {
		struct aiv_gk20a *l = g->gr.ctx_vars.ctxsw_regs.sys.l;
		g->sim->esc_readl(g, "GRCTX_REG_LIST_SYS:ADDR",
				    i, &l[i].addr);
		g->sim->esc_readl(g, "GRCTX_REG_LIST_SYS:INDEX",
				    i, &l[i].index);
		g->sim->esc_readl(g, "GRCTX_REG_LIST_SYS:VALUE",
				    i, &l[i].value);
	}

	for (i = 0; i < g->gr.ctx_vars.ctxsw_regs.gpc.count; i++) {
		struct aiv_gk20a *l = g->gr.ctx_vars.ctxsw_regs.gpc.l;
		g->sim->esc_readl(g, "GRCTX_REG_LIST_GPC:ADDR",
				    i, &l[i].addr);
		g->sim->esc_readl(g, "GRCTX_REG_LIST_GPC:INDEX",
				    i, &l[i].index);
		g->sim->esc_readl(g, "GRCTX_REG_LIST_GPC:VALUE",
				    i, &l[i].value);
	}

	for (i = 0; i < g->gr.ctx_vars.ctxsw_regs.tpc.count; i++) {
		struct aiv_gk20a *l = g->gr.ctx_vars.ctxsw_regs.tpc.l;
		g->sim->esc_readl(g, "GRCTX_REG_LIST_TPC:ADDR",
				    i, &l[i].addr);
		g->sim->esc_readl(g, "GRCTX_REG_LIST_TPC:INDEX",
				    i, &l[i].index);
		g->sim->esc_readl(g, "GRCTX_REG_LIST_TPC:VALUE",
				    i, &l[i].value);
	}

	for (i = 0; i < g->gr.ctx_vars.ctxsw_regs.ppc.count; i++) {
		struct aiv_gk20a *l = g->gr.ctx_vars.ctxsw_regs.ppc.l;
		g->sim->esc_readl(g, "GRCTX_REG_LIST_PPC:ADDR",
				    i, &l[i].addr);
		g->sim->esc_readl(g, "GRCTX_REG_LIST_PPC:INDEX",
				    i, &l[i].index);
		g->sim->esc_readl(g, "GRCTX_REG_LIST_PPC:VALUE",
				    i, &l[i].value);
	}

	for (i = 0; i < g->gr.ctx_vars.ctxsw_regs.zcull_gpc.count; i++) {
		struct aiv_gk20a *l = g->gr.ctx_vars.ctxsw_regs.zcull_gpc.l;
		g->sim->esc_readl(g, "GRCTX_REG_LIST_ZCULL_GPC:ADDR",
				    i, &l[i].addr);
		g->sim->esc_readl(g, "GRCTX_REG_LIST_ZCULL_GPC:INDEX",
				    i, &l[i].index);
		g->sim->esc_readl(g, "GRCTX_REG_LIST_ZCULL_GPC:VALUE",
				    i, &l[i].value);
	}

	for (i = 0; i < g->gr.ctx_vars.ctxsw_regs.pm_sys.count; i++) {
		struct aiv_gk20a *l = g->gr.ctx_vars.ctxsw_regs.pm_sys.l;
		g->sim->esc_readl(g, "GRCTX_REG_LIST_PM_SYS:ADDR",
				    i, &l[i].addr);
		g->sim->esc_readl(g, "GRCTX_REG_LIST_PM_SYS:INDEX",
				    i, &l[i].index);
		g->sim->esc_readl(g, "GRCTX_REG_LIST_PM_SYS:VALUE",
				    i, &l[i].value);
	}

	for (i = 0; i < g->gr.ctx_vars.ctxsw_regs.pm_gpc.count; i++) {
		struct aiv_gk20a *l = g->gr.ctx_vars.ctxsw_regs.pm_gpc.l;
		g->sim->esc_readl(g, "GRCTX_REG_LIST_PM_GPC:ADDR",
				    i, &l[i].addr);
		g->sim->esc_readl(g, "GRCTX_REG_LIST_PM_GPC:INDEX",
				    i, &l[i].index);
		g->sim->esc_readl(g, "GRCTX_REG_LIST_PM_GPC:VALUE",
				    i, &l[i].value);
	}

	for (i = 0; i < g->gr.ctx_vars.ctxsw_regs.pm_tpc.count; i++) {
		struct aiv_gk20a *l = g->gr.ctx_vars.ctxsw_regs.pm_tpc.l;
		g->sim->esc_readl(g, "GRCTX_REG_LIST_PM_TPC:ADDR",
				    i, &l[i].addr);
		g->sim->esc_readl(g, "GRCTX_REG_LIST_PM_TPC:INDEX",
				    i, &l[i].index);
		g->sim->esc_readl(g, "GRCTX_REG_LIST_PM_TPC:VALUE",
				    i, &l[i].value);
	}

	nvgpu_log(g, gpu_dbg_info | gpu_dbg_fn, "query GRCTX_REG_LIST_ETPC");
	for (i = 0; i < g->gr.ctx_vars.ctxsw_regs.etpc.count; i++) {
		struct aiv_gk20a *l = g->gr.ctx_vars.ctxsw_regs.etpc.l;
		g->sim->esc_readl(g, "GRCTX_REG_LIST_ETPC:ADDR",
				    i, &l[i].addr);
		g->sim->esc_readl(g, "GRCTX_REG_LIST_ETPC:INDEX",
				    i, &l[i].index);
		g->sim->esc_readl(g, "GRCTX_REG_LIST_ETPC:VALUE",
				    i, &l[i].value);
		nvgpu_log(g, gpu_dbg_info | gpu_dbg_fn,
				"addr:0x%#08x index:0x%08x value:0x%08x",
				l[i].addr, l[i].index, l[i].value);
	}

	g->gr.ctx_vars.valid = true;

	g->sim->esc_readl(g, "GRCTX_GEN_CTX_REGS_BASE_INDEX", 0,
			    &g->gr.ctx_vars.regs_base_index);

	nvgpu_log(g, gpu_dbg_info | gpu_dbg_fn, "finished querying grctx info from chiplib");
	return 0;
fail:
	nvgpu_err(g, "failed querying grctx info from chiplib");
	return err;

}
