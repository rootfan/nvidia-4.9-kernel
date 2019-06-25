/*
 * Copyright (c) 2016-2018, NVIDIA CORPORATION.  All rights reserved.
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

#include <nvgpu/nvgpu_common.h>
#include <nvgpu/kmem.h>
#include <nvgpu/dma.h>
#include <nvgpu/acr/nvgpu_acr.h>
#include <nvgpu/firmware.h>
#include <nvgpu/pmu.h>
#include <nvgpu/enabled.h>

#include "gk20a/gk20a.h"
#include "gk20a/pmu_gk20a.h"

#include "gm20b/mm_gm20b.h"
#include "gm20b/acr_gm20b.h"
#include "gp106/acr_gp106.h"
#include "gp106/pmu_gp106.h"
#include "gv100/acr_gv100.h"

#include "sec2_gp106.h"

#include <nvgpu/hw/gp106/hw_psec_gp106.h>
#include <nvgpu/hw/gp106/hw_pwr_gp106.h>

/*Defines*/
#define gp106_dbg_pmu(g, fmt, arg...) \
	nvgpu_log(g, gpu_dbg_pmu, fmt, ##arg)

typedef int (*get_ucode_details)(struct gk20a *g,
		struct flcn_ucode_img_v1 *udata);

/* Both size and address of WPR need to be 128K-aligned */
#define WPR_ALIGNMENT	0x20000
#define GP106_DGPU_NONWPR NVGPU_VIDMEM_BOOTSTRAP_ALLOCATOR_BASE
#define GP106_DGPU_WPR_OFFSET 0x400000
#define DGPU_WPR_SIZE 0x100000

/*Externs*/

/*Forwards*/

/*Globals*/
static get_ucode_details pmu_acr_supp_ucode_list[] = {
	pmu_ucode_details,
	fecs_ucode_details,
	gpccs_ucode_details,
};

void gp106_wpr_info(struct gk20a *g, struct wpr_carveout_info *inf)
{
	inf->nonwpr_base = g->mm.vidmem.bootstrap_base;
	inf->wpr_base = inf->nonwpr_base + GP106_DGPU_WPR_OFFSET;
	inf->size = DGPU_WPR_SIZE;
}

static void flcn64_set_dma(struct falc_u64 *dma_addr, u64 value)
{
	dma_addr->lo |= u64_lo32(value);
	dma_addr->hi |= u64_hi32(value);
}

int gp106_alloc_blob_space(struct gk20a *g,
		size_t size, struct nvgpu_mem *mem)
{
	struct wpr_carveout_info wpr_inf;
	int err;

	if (mem->size)
		return 0;

	g->ops.pmu.get_wpr(g, &wpr_inf);

	/*
	 * Even though this mem_desc wouldn't be used, the wpr region needs to
	 * be reserved in the allocator.
	 */
	err = nvgpu_dma_alloc_flags_vid_at(g,
			NVGPU_DMA_NO_KERNEL_MAPPING, wpr_inf.size,
			&g->acr.wpr_dummy, wpr_inf.wpr_base);
	if (err)
		return err;

	return nvgpu_dma_alloc_flags_vid_at(g,
			NVGPU_DMA_NO_KERNEL_MAPPING, wpr_inf.size, mem,
			wpr_inf.nonwpr_base);
}
/* TODO - check if any free blob res needed*/

int pmu_ucode_details(struct gk20a *g, struct flcn_ucode_img_v1 *p_img)
{
	struct nvgpu_firmware *pmu_fw, *pmu_desc, *pmu_sig;
	struct nvgpu_pmu *pmu = &g->pmu;
	struct lsf_ucode_desc_v1 *lsf_desc;
	int err;

	gp106_dbg_pmu(g, "requesting PMU ucode in gp106\n");
	pmu_fw = nvgpu_request_firmware(g, GM20B_PMU_UCODE_IMAGE,
					NVGPU_REQUEST_FIRMWARE_NO_SOC);
	if (!pmu_fw) {
		nvgpu_err(g, "failed to load pmu ucode!!");
		return -ENOENT;
	}
	g->acr.pmu_fw = pmu_fw;
	gp106_dbg_pmu(g, "Loaded PMU ucode in for blob preparation");

	gp106_dbg_pmu(g, "requesting PMU ucode desc in GM20B\n");
	pmu_desc = nvgpu_request_firmware(g, GM20B_PMU_UCODE_DESC,
					NVGPU_REQUEST_FIRMWARE_NO_SOC);
	if (!pmu_desc) {
		nvgpu_err(g, "failed to load pmu ucode desc!!");
		err = -ENOENT;
		goto release_img_fw;
	}
	pmu_sig = nvgpu_request_firmware(g, GM20B_PMU_UCODE_SIG,
					NVGPU_REQUEST_FIRMWARE_NO_SOC);
	if (!pmu_sig) {
		nvgpu_err(g, "failed to load pmu sig!!");
		err = -ENOENT;
		goto release_desc;
	}
	pmu->desc_v1 = (struct pmu_ucode_desc_v1 *)pmu_desc->data;
	pmu->ucode_image = (u32 *)pmu_fw->data;
	g->acr.pmu_desc = pmu_desc;

	err = nvgpu_init_pmu_fw_support(pmu);
	if (err) {
		nvgpu_err(g, "failed to set function pointers");
		goto release_sig;
	}

	lsf_desc = nvgpu_kzalloc(g, sizeof(struct lsf_ucode_desc_v1));
	if (!lsf_desc) {
		err = -ENOMEM;
		goto release_sig;
	}
	memcpy(lsf_desc, (void *)pmu_sig->data,
			min_t(size_t, sizeof(*lsf_desc), pmu_sig->size));
	lsf_desc->falcon_id = LSF_FALCON_ID_PMU;

	p_img->desc = pmu->desc_v1;
	p_img->data = pmu->ucode_image;
	p_img->data_size = pmu->desc_v1->app_start_offset
						+ pmu->desc_v1->app_size;
	p_img->fw_ver = NULL;
	p_img->header = NULL;
	p_img->lsf_desc = (struct lsf_ucode_desc_v1 *)lsf_desc;
	gp106_dbg_pmu(g, "requesting PMU ucode in GM20B exit\n");

	nvgpu_release_firmware(g, pmu_sig);
	return 0;
release_sig:
	nvgpu_release_firmware(g, pmu_sig);
release_desc:
	nvgpu_release_firmware(g, pmu_desc);
	g->acr.pmu_desc = NULL;
release_img_fw:
	nvgpu_release_firmware(g, pmu_fw);
	g->acr.pmu_fw = NULL;
	return err;
}

int fecs_ucode_details(struct gk20a *g, struct flcn_ucode_img_v1 *p_img)
{
	u32 ver = g->params.gpu_arch + g->params.gpu_impl;
	struct lsf_ucode_desc_v1 *lsf_desc;
	struct nvgpu_firmware *fecs_sig = NULL;
	int err;

	switch (ver) {
		case NVGPU_GPUID_GP104:
			fecs_sig = nvgpu_request_firmware(g,
					GP104_FECS_UCODE_SIG,
					NVGPU_REQUEST_FIRMWARE_NO_SOC);
			break;
		case NVGPU_GPUID_GP106:
			fecs_sig = nvgpu_request_firmware(g,
					GP106_FECS_UCODE_SIG,
					NVGPU_REQUEST_FIRMWARE_NO_SOC);
			break;
		case NVGPU_GPUID_GV11B:
			fecs_sig = nvgpu_request_firmware(g,
					GM20B_FECS_UCODE_SIG, 0);
			break;
		case NVGPU_GPUID_GV100:
			fecs_sig = nvgpu_request_firmware(g,
					GV100_FECS_UCODE_SIG,
					NVGPU_REQUEST_FIRMWARE_NO_SOC);
			break;
		default:
			nvgpu_err(g, "no support for GPUID %x", ver);
	}

	if (!fecs_sig) {
		nvgpu_err(g, "failed to load fecs sig");
		return -ENOENT;
	}
	lsf_desc = nvgpu_kzalloc(g, sizeof(struct lsf_ucode_desc_v1));
	if (!lsf_desc) {
		err = -ENOMEM;
		goto rel_sig;
	}
	memcpy(lsf_desc, (void *)fecs_sig->data,
			min_t(size_t, sizeof(*lsf_desc), fecs_sig->size));
	lsf_desc->falcon_id = LSF_FALCON_ID_FECS;

	p_img->desc = nvgpu_kzalloc(g, sizeof(struct pmu_ucode_desc_v1));
	if (p_img->desc == NULL) {
		err = -ENOMEM;
		goto free_lsf_desc;
	}

	p_img->desc->bootloader_start_offset =
		g->ctxsw_ucode_info.fecs.boot.offset;
	p_img->desc->bootloader_size =
		ALIGN(g->ctxsw_ucode_info.fecs.boot.size, 256);
	p_img->desc->bootloader_imem_offset =
		g->ctxsw_ucode_info.fecs.boot_imem_offset;
	p_img->desc->bootloader_entry_point =
		g->ctxsw_ucode_info.fecs.boot_entry;

	p_img->desc->image_size =
		ALIGN(g->ctxsw_ucode_info.fecs.boot.size, 256) +
		ALIGN(g->ctxsw_ucode_info.fecs.code.size, 256) +
		ALIGN(g->ctxsw_ucode_info.fecs.data.size, 256);
	p_img->desc->app_size = ALIGN(g->ctxsw_ucode_info.fecs.code.size, 256) +
		ALIGN(g->ctxsw_ucode_info.fecs.data.size, 256);
	p_img->desc->app_start_offset = g->ctxsw_ucode_info.fecs.code.offset;
	p_img->desc->app_imem_offset = 0;
	p_img->desc->app_imem_entry = 0;
	p_img->desc->app_dmem_offset = 0;
	p_img->desc->app_resident_code_offset = 0;
	p_img->desc->app_resident_code_size =
		g->ctxsw_ucode_info.fecs.code.size;
	p_img->desc->app_resident_data_offset =
		g->ctxsw_ucode_info.fecs.data.offset -
		g->ctxsw_ucode_info.fecs.code.offset;
	p_img->desc->app_resident_data_size =
		g->ctxsw_ucode_info.fecs.data.size;
	p_img->data = g->ctxsw_ucode_info.surface_desc.cpu_va;
	p_img->data_size = p_img->desc->image_size;

	p_img->fw_ver = NULL;
	p_img->header = NULL;
	p_img->lsf_desc = (struct lsf_ucode_desc_v1 *)lsf_desc;
	gp106_dbg_pmu(g, "fecs fw loaded\n");
	nvgpu_release_firmware(g, fecs_sig);
	return 0;
free_lsf_desc:
	nvgpu_kfree(g, lsf_desc);
rel_sig:
	nvgpu_release_firmware(g, fecs_sig);
	return err;
}

int gpccs_ucode_details(struct gk20a *g, struct flcn_ucode_img_v1 *p_img)
{
	u32 ver = g->params.gpu_arch + g->params.gpu_impl;
	struct lsf_ucode_desc_v1 *lsf_desc;
	struct nvgpu_firmware *gpccs_sig = NULL;
	int err;

	if (!nvgpu_is_enabled(g, NVGPU_SEC_SECUREGPCCS))
		return -ENOENT;

	switch (ver) {
		case NVGPU_GPUID_GP104:
			gpccs_sig = nvgpu_request_firmware(g,
					GP104_GPCCS_UCODE_SIG,
					NVGPU_REQUEST_FIRMWARE_NO_SOC);
			break;
		case NVGPU_GPUID_GP106:
			gpccs_sig = nvgpu_request_firmware(g,
					GP106_GPCCS_UCODE_SIG,
					NVGPU_REQUEST_FIRMWARE_NO_SOC);
			break;
		case NVGPU_GPUID_GV11B:
			gpccs_sig = nvgpu_request_firmware(g,
					T18x_GPCCS_UCODE_SIG, 0);
			break;
		case NVGPU_GPUID_GV100:
			gpccs_sig = nvgpu_request_firmware(g,
					GV100_GPCCS_UCODE_SIG,
					NVGPU_REQUEST_FIRMWARE_NO_SOC);
			break;
		default:
			nvgpu_err(g, "no support for GPUID %x", ver);
	}

	if (!gpccs_sig) {
		nvgpu_err(g, "failed to load gpccs sig");
		return -ENOENT;
	}
	lsf_desc = nvgpu_kzalloc(g, sizeof(struct lsf_ucode_desc_v1));
	if (!lsf_desc) {
		err = -ENOMEM;
		goto rel_sig;
	}
	memcpy(lsf_desc, (void *)gpccs_sig->data,
			min_t(size_t, sizeof(*lsf_desc), gpccs_sig->size));
	lsf_desc->falcon_id = LSF_FALCON_ID_GPCCS;

	p_img->desc = nvgpu_kzalloc(g, sizeof(struct pmu_ucode_desc_v1));
	if (p_img->desc == NULL) {
		err = -ENOMEM;
		goto free_lsf_desc;
	}

	p_img->desc->bootloader_start_offset =
		0;
	p_img->desc->bootloader_size =
		ALIGN(g->ctxsw_ucode_info.gpccs.boot.size, 256);
	p_img->desc->bootloader_imem_offset =
		g->ctxsw_ucode_info.gpccs.boot_imem_offset;
	p_img->desc->bootloader_entry_point =
		g->ctxsw_ucode_info.gpccs.boot_entry;

	p_img->desc->image_size =
		ALIGN(g->ctxsw_ucode_info.gpccs.boot.size, 256) +
		ALIGN(g->ctxsw_ucode_info.gpccs.code.size, 256) +
		ALIGN(g->ctxsw_ucode_info.gpccs.data.size, 256);
	p_img->desc->app_size = ALIGN(g->ctxsw_ucode_info.gpccs.code.size, 256)
		+ ALIGN(g->ctxsw_ucode_info.gpccs.data.size, 256);
	p_img->desc->app_start_offset = p_img->desc->bootloader_size;
	p_img->desc->app_imem_offset = 0;
	p_img->desc->app_imem_entry = 0;
	p_img->desc->app_dmem_offset = 0;
	p_img->desc->app_resident_code_offset = 0;
	p_img->desc->app_resident_code_size =
		ALIGN(g->ctxsw_ucode_info.gpccs.code.size, 256);
	p_img->desc->app_resident_data_offset =
		ALIGN(g->ctxsw_ucode_info.gpccs.data.offset, 256) -
		ALIGN(g->ctxsw_ucode_info.gpccs.code.offset, 256);
	p_img->desc->app_resident_data_size =
		ALIGN(g->ctxsw_ucode_info.gpccs.data.size, 256);
	p_img->data = (u32 *)((u8 *)g->ctxsw_ucode_info.surface_desc.cpu_va +
		g->ctxsw_ucode_info.gpccs.boot.offset);
	p_img->data_size = ALIGN(p_img->desc->image_size, 256);
	p_img->fw_ver = NULL;
	p_img->header = NULL;
	p_img->lsf_desc = (struct lsf_ucode_desc_v1 *)lsf_desc;
	gp106_dbg_pmu(g, "gpccs fw loaded\n");
	nvgpu_release_firmware(g, gpccs_sig);
	return 0;
free_lsf_desc:
	nvgpu_kfree(g, lsf_desc);
rel_sig:
	nvgpu_release_firmware(g, gpccs_sig);
	return err;
}

int gp106_prepare_ucode_blob(struct gk20a *g)
{

	int err;
	struct ls_flcn_mgr_v1 lsfm_l, *plsfm;
	struct nvgpu_pmu *pmu = &g->pmu;
	struct wpr_carveout_info wpr_inf;

	if (g->acr.ucode_blob.cpu_va) {
		/*Recovery case, we do not need to form
		non WPR blob of ucodes*/
		err = nvgpu_init_pmu_fw_support(pmu);
		if (err) {
			gp106_dbg_pmu(g, "failed to set function pointers\n");
			return err;
		}
		return 0;
	}
	plsfm = &lsfm_l;
	memset((void *)plsfm, 0, sizeof(struct ls_flcn_mgr_v1));
	gr_gk20a_init_ctxsw_ucode(g);

	g->ops.pmu.get_wpr(g, &wpr_inf);
	gp106_dbg_pmu(g, "wpr carveout base:%llx\n", (wpr_inf.wpr_base));
	gp106_dbg_pmu(g, "wpr carveout size :%x\n", (u32)wpr_inf.size);

	/* Discover all managed falcons*/
	err = lsfm_discover_ucode_images(g, plsfm);
	gp106_dbg_pmu(g, " Managed Falcon cnt %d\n", plsfm->managed_flcn_cnt);
	if (err)
		goto exit_err;

	if (plsfm->managed_flcn_cnt && !g->acr.ucode_blob.cpu_va) {
		/* Generate WPR requirements*/
		err = lsf_gen_wpr_requirements(g, plsfm);
		if (err)
			goto exit_err;

		/*Alloc memory to hold ucode blob contents*/
		err = g->ops.pmu.alloc_blob_space(g, plsfm->wpr_size
							,&g->acr.ucode_blob);
		if (err)
			goto exit_err;

		gp106_dbg_pmu(g, "managed LS falcon %d, WPR size %d bytes.\n",
			plsfm->managed_flcn_cnt, plsfm->wpr_size);

		lsfm_init_wpr_contents(g, plsfm, &g->acr.ucode_blob);
	} else {
		gp106_dbg_pmu(g, "LSFM is managing no falcons.\n");
	}
	gp106_dbg_pmu(g, "prepare ucode blob return 0\n");
	free_acr_resources(g, plsfm);

 exit_err:
	return err;
}

static u8 lsfm_falcon_disabled(struct gk20a *g, struct ls_flcn_mgr_v1 *plsfm,
	u32 falcon_id)
{
	return (plsfm->disable_mask >> falcon_id) & 0x1;
}

/* Discover all managed falcon ucode images */
int lsfm_discover_ucode_images(struct gk20a *g,
	struct ls_flcn_mgr_v1 *plsfm)
{
	struct nvgpu_pmu *pmu = &g->pmu;
	struct flcn_ucode_img_v1 ucode_img;
	u32 falcon_id;
	u32 i;
	int status;

	/* LSFM requires a secure PMU, discover it first.*/
	/* Obtain the PMU ucode image and add it to the list if required*/
	memset(&ucode_img, 0, sizeof(ucode_img));
	status = pmu_ucode_details(g, &ucode_img);
	if (status)
		return status;

	if (ucode_img.lsf_desc != NULL) {
		/* The falon_id is formed by grabbing the static base
		 * falon_id from the image and adding the
		 * engine-designated falcon instance.*/
		pmu->pmu_mode |= PMU_SECURE_MODE;
		falcon_id = ucode_img.lsf_desc->falcon_id +
			ucode_img.flcn_inst;

		if (!lsfm_falcon_disabled(g, plsfm, falcon_id)) {
			pmu->falcon_id = falcon_id;
			if (lsfm_add_ucode_img(g, plsfm, &ucode_img,
				pmu->falcon_id) == 0)
				pmu->pmu_mode |= PMU_LSFM_MANAGED;

			plsfm->managed_flcn_cnt++;
		} else {
			gp106_dbg_pmu(g, "id not managed %d\n",
				ucode_img.lsf_desc->falcon_id);
		}
	}

	/*Free any ucode image resources if not managing this falcon*/
	if (!(pmu->pmu_mode & PMU_LSFM_MANAGED)) {
		gp106_dbg_pmu(g, "pmu is not LSFM managed\n");
		lsfm_free_ucode_img_res(g, &ucode_img);
	}

	/* Enumerate all constructed falcon objects,
	 as we need the ucode image info and total falcon count.*/

	/*0th index is always PMU which is already handled in earlier
	if condition*/
	for (i = 1; i < (MAX_SUPPORTED_LSFM); i++) {
		memset(&ucode_img, 0, sizeof(ucode_img));
		if (pmu_acr_supp_ucode_list[i](g, &ucode_img) == 0) {
			if (ucode_img.lsf_desc != NULL) {
				/* We have engine sigs, ensure that this falcon
				is aware of the secure mode expectations
				(ACR status)*/

				/* falon_id is formed by grabbing the static
				base falonId from the image and adding the
				engine-designated falcon instance. */
				falcon_id = ucode_img.lsf_desc->falcon_id +
					ucode_img.flcn_inst;

				if (!lsfm_falcon_disabled(g, plsfm,
					falcon_id)) {
					/* Do not manage non-FB ucode*/
					if (lsfm_add_ucode_img(g,
						plsfm, &ucode_img, falcon_id)
						== 0)
						plsfm->managed_flcn_cnt++;
				} else {
					gp106_dbg_pmu(g, "not managed %d\n",
						ucode_img.lsf_desc->falcon_id);
					lsfm_free_nonpmu_ucode_img_res(g,
						&ucode_img);
				}
			}
		} else {
			/* Consumed all available falcon objects */
			gp106_dbg_pmu(g, "Done checking for ucodes %d\n", i);
			break;
		}
	}
	return 0;
}

int gp106_pmu_populate_loader_cfg(struct gk20a *g,
	void *lsfm, u32 *p_bl_gen_desc_size)
{
	struct wpr_carveout_info wpr_inf;
	struct nvgpu_pmu *pmu = &g->pmu;
	struct lsfm_managed_ucode_img_v2 *p_lsfm =
		(struct lsfm_managed_ucode_img_v2 *)lsfm;
	struct flcn_ucode_img_v1 *p_img = &(p_lsfm->ucode_img);
	struct flcn_bl_dmem_desc_v1 *ldr_cfg =
				&(p_lsfm->bl_gen_desc.bl_dmem_desc_v1);
	u64 addr_base;
	struct pmu_ucode_desc_v1 *desc;
	u64 addr_code, addr_data;
	u32 addr_args;

	if (p_img->desc == NULL) /*This means its a header based ucode,
				  and so we do not fill BL gen desc structure*/
		return -EINVAL;
	desc = p_img->desc;
	/*
	 Calculate physical and virtual addresses for various portions of
	 the PMU ucode image
	 Calculate the 32-bit addresses for the application code, application
	 data, and bootloader code. These values are all based on IM_BASE.
	 The 32-bit addresses will be the upper 32-bits of the virtual or
	 physical addresses of each respective segment.
	*/
	addr_base = p_lsfm->lsb_header.ucode_off;
	g->ops.pmu.get_wpr(g, &wpr_inf);
	addr_base += (wpr_inf.wpr_base);

	gp106_dbg_pmu(g, "pmu loader cfg addrbase 0x%llx\n", addr_base);
	/*From linux*/
	addr_code = addr_base +
				desc->app_start_offset +
				desc->app_resident_code_offset;
	gp106_dbg_pmu(g, "app start %d app res code off %d\n",
		desc->app_start_offset, desc->app_resident_code_offset);
	addr_data = addr_base +
				desc->app_start_offset +
				desc->app_resident_data_offset;
	gp106_dbg_pmu(g, "app res data offset%d\n",
		desc->app_resident_data_offset);
	gp106_dbg_pmu(g, "bl start off %d\n", desc->bootloader_start_offset);

	addr_args = ((pwr_falcon_hwcfg_dmem_size_v(
			gk20a_readl(g, pwr_falcon_hwcfg_r())))
			<< GK20A_PMU_DMEM_BLKSIZE2);

	addr_args -= g->ops.pmu_ver.get_pmu_cmdline_args_size(pmu);

	gp106_dbg_pmu(g, "addr_args %x\n", addr_args);

	/* Populate the LOADER_CONFIG state */
	memset((void *) ldr_cfg, 0, sizeof(struct flcn_bl_dmem_desc_v1));
	ldr_cfg->ctx_dma = GK20A_PMU_DMAIDX_UCODE;
	flcn64_set_dma(&ldr_cfg->code_dma_base, addr_code);
	ldr_cfg->non_sec_code_off = desc->app_resident_code_offset;
	ldr_cfg->non_sec_code_size = desc->app_resident_code_size;
	flcn64_set_dma(&ldr_cfg->data_dma_base, addr_data);
	ldr_cfg->data_size = desc->app_resident_data_size;
	ldr_cfg->code_entry_point = desc->app_imem_entry;

	/* Update the argc/argv members*/
	ldr_cfg->argc = 1;
	ldr_cfg->argv = addr_args;

	*p_bl_gen_desc_size = sizeof(struct flcn_bl_dmem_desc_v1);

	g->acr.pmu_args = addr_args;
	return 0;
}

int gp106_flcn_populate_bl_dmem_desc(struct gk20a *g,
	void *lsfm, u32 *p_bl_gen_desc_size, u32 falconid)
{
	struct wpr_carveout_info wpr_inf;
	struct lsfm_managed_ucode_img_v2 *p_lsfm =
			(struct lsfm_managed_ucode_img_v2 *)lsfm;
	struct flcn_ucode_img_v1 *p_img = &(p_lsfm->ucode_img);
	struct flcn_bl_dmem_desc_v1 *ldr_cfg =
			&(p_lsfm->bl_gen_desc.bl_dmem_desc_v1);
	u64 addr_base;
	struct pmu_ucode_desc_v1 *desc;
	u64 addr_code, addr_data;

	if (p_img->desc == NULL) /*This means its a header based ucode,
				  and so we do not fill BL gen desc structure*/
		return -EINVAL;
	desc = p_img->desc;

	/*
	 Calculate physical and virtual addresses for various portions of
	 the PMU ucode image
	 Calculate the 32-bit addresses for the application code, application
	 data, and bootloader code. These values are all based on IM_BASE.
	 The 32-bit addresses will be the upper 32-bits of the virtual or
	 physical addresses of each respective segment.
	*/
	addr_base = p_lsfm->lsb_header.ucode_off;
	g->ops.pmu.get_wpr(g, &wpr_inf);
	addr_base += wpr_inf.wpr_base;

	gp106_dbg_pmu(g, "falcon ID %x", p_lsfm->wpr_header.falcon_id);
	gp106_dbg_pmu(g, "gen loader cfg addrbase %llx ", addr_base);
	addr_code = addr_base +
				desc->app_start_offset +
				desc->app_resident_code_offset;
	addr_data = addr_base +
				desc->app_start_offset +
				desc->app_resident_data_offset;

	gp106_dbg_pmu(g, "gen cfg addrcode %llx data %llx load offset %x",
			addr_code, addr_data, desc->bootloader_start_offset);

	/* Populate the LOADER_CONFIG state */
	memset((void *) ldr_cfg, 0, sizeof(struct flcn_bl_dmem_desc_v1));
	ldr_cfg->ctx_dma = GK20A_PMU_DMAIDX_UCODE;
	flcn64_set_dma(&ldr_cfg->code_dma_base, addr_code);
	ldr_cfg->non_sec_code_size = desc->app_resident_code_size;
	flcn64_set_dma(&ldr_cfg->data_dma_base, addr_data);
	ldr_cfg->data_size = desc->app_resident_data_size;
	ldr_cfg->code_entry_point = desc->app_imem_entry;

	*p_bl_gen_desc_size = sizeof(struct flcn_bl_dmem_desc_v1);
	return 0;
}

/* Populate falcon boot loader generic desc.*/
int lsfm_fill_flcn_bl_gen_desc(struct gk20a *g,
		struct lsfm_managed_ucode_img_v2 *pnode)
{

	struct nvgpu_pmu *pmu = &g->pmu;
	if (pnode->wpr_header.falcon_id != pmu->falcon_id) {
		gp106_dbg_pmu(g, "non pmu. write flcn bl gen desc\n");
		g->ops.pmu.flcn_populate_bl_dmem_desc(g,
				pnode, &pnode->bl_gen_desc_size,
					pnode->wpr_header.falcon_id);
		return 0;
	}

	if (pmu->pmu_mode & PMU_LSFM_MANAGED) {
		gp106_dbg_pmu(g, "pmu write flcn bl gen desc\n");
		if (pnode->wpr_header.falcon_id == pmu->falcon_id)
			return g->ops.pmu.pmu_populate_loader_cfg(g, pnode,
				&pnode->bl_gen_desc_size);
	}

	/* Failed to find the falcon requested. */
	return -ENOENT;
}

/* Initialize WPR contents */
void lsfm_init_wpr_contents(struct gk20a *g,
		struct ls_flcn_mgr_v1 *plsfm, struct nvgpu_mem *ucode)
{
	struct lsfm_managed_ucode_img_v2 *pnode = plsfm->ucode_img_list;
	struct lsf_wpr_header_v1 last_wpr_hdr;
	u32 i;

	/* The WPR array is at the base of the WPR */
	pnode = plsfm->ucode_img_list;
	memset(&last_wpr_hdr, 0, sizeof(struct lsf_wpr_header_v1));
	i = 0;

	/*
	 * Walk the managed falcons, flush WPR and LSB headers to FB.
	 * flush any bl args to the storage area relative to the
	 * ucode image (appended on the end as a DMEM area).
	 */
	while (pnode) {
		/* Flush WPR header to memory*/
		nvgpu_mem_wr_n(g, ucode, i * sizeof(pnode->wpr_header),
				&pnode->wpr_header, sizeof(pnode->wpr_header));

		gp106_dbg_pmu(g, "wpr header");
		gp106_dbg_pmu(g, "falconid :%d",
				pnode->wpr_header.falcon_id);
		gp106_dbg_pmu(g, "lsb_offset :%x",
				pnode->wpr_header.lsb_offset);
		gp106_dbg_pmu(g, "bootstrap_owner :%d",
			pnode->wpr_header.bootstrap_owner);
		gp106_dbg_pmu(g, "lazy_bootstrap :%d",
				pnode->wpr_header.lazy_bootstrap);
		gp106_dbg_pmu(g, "status :%d",
				pnode->wpr_header.status);

		/*Flush LSB header to memory*/
		nvgpu_mem_wr_n(g, ucode, pnode->wpr_header.lsb_offset,
				&pnode->lsb_header, sizeof(pnode->lsb_header));

		gp106_dbg_pmu(g, "lsb header");
		gp106_dbg_pmu(g, "ucode_off :%x",
				pnode->lsb_header.ucode_off);
		gp106_dbg_pmu(g, "ucode_size :%x",
				pnode->lsb_header.ucode_size);
		gp106_dbg_pmu(g, "data_size :%x",
				pnode->lsb_header.data_size);
		gp106_dbg_pmu(g, "bl_code_size :%x",
				pnode->lsb_header.bl_code_size);
		gp106_dbg_pmu(g, "bl_imem_off :%x",
				pnode->lsb_header.bl_imem_off);
		gp106_dbg_pmu(g, "bl_data_off :%x",
				pnode->lsb_header.bl_data_off);
		gp106_dbg_pmu(g, "bl_data_size :%x",
				pnode->lsb_header.bl_data_size);
		gp106_dbg_pmu(g, "app_code_off :%x",
				pnode->lsb_header.app_code_off);
		gp106_dbg_pmu(g, "app_code_size :%x",
				pnode->lsb_header.app_code_size);
		gp106_dbg_pmu(g, "app_data_off :%x",
				pnode->lsb_header.app_data_off);
		gp106_dbg_pmu(g, "app_data_size :%x",
				pnode->lsb_header.app_data_size);
		gp106_dbg_pmu(g, "flags :%x",
				pnode->lsb_header.flags);

		/*If this falcon has a boot loader and related args,
		 * flush them.*/
		if (!pnode->ucode_img.header) {
			/*Populate gen bl and flush to memory*/
			lsfm_fill_flcn_bl_gen_desc(g, pnode);
			nvgpu_mem_wr_n(g, ucode,
					pnode->lsb_header.bl_data_off,
					&pnode->bl_gen_desc,
					pnode->bl_gen_desc_size);
		}
		/*Copying of ucode*/
		nvgpu_mem_wr_n(g, ucode, pnode->lsb_header.ucode_off,
				pnode->ucode_img.data,
				pnode->ucode_img.data_size);
		pnode = pnode->next;
		i++;
	}

	/* Tag the terminator WPR header with an invalid falcon ID. */
	last_wpr_hdr.falcon_id = LSF_FALCON_ID_INVALID;
	nvgpu_mem_wr_n(g, ucode,
		plsfm->managed_flcn_cnt * sizeof(struct lsf_wpr_header_v1),
		&last_wpr_hdr,
		sizeof(struct lsf_wpr_header_v1));
}

/*!
 * lsfm_parse_no_loader_ucode: parses UCODE header of falcon
 *
 * @param[in] p_ucodehdr : UCODE header
 * @param[out] lsb_hdr : updates values in LSB header
 *
 * @return 0
 */
static int lsfm_parse_no_loader_ucode(u32 *p_ucodehdr,
	struct lsf_lsb_header_v1 *lsb_hdr)
{

	u32 code_size = 0;
	u32 data_size = 0;
	u32 i = 0;
	u32 total_apps = p_ucodehdr[FLCN_NL_UCODE_HDR_NUM_APPS_IND];

	/* Lets calculate code size*/
	code_size += p_ucodehdr[FLCN_NL_UCODE_HDR_OS_CODE_SIZE_IND];
	for (i = 0; i < total_apps; i++) {
		code_size += p_ucodehdr[FLCN_NL_UCODE_HDR_APP_CODE_SIZE_IND
			(total_apps, i)];
	}
	code_size += p_ucodehdr[FLCN_NL_UCODE_HDR_OS_OVL_SIZE_IND(total_apps)];

	/* Calculate data size*/
	data_size += p_ucodehdr[FLCN_NL_UCODE_HDR_OS_DATA_SIZE_IND];
	for (i = 0; i < total_apps; i++) {
		data_size += p_ucodehdr[FLCN_NL_UCODE_HDR_APP_DATA_SIZE_IND
			(total_apps, i)];
	}

	lsb_hdr->ucode_size = code_size;
	lsb_hdr->data_size = data_size;
	lsb_hdr->bl_code_size = p_ucodehdr[FLCN_NL_UCODE_HDR_OS_CODE_SIZE_IND];
	lsb_hdr->bl_imem_off = 0;
	lsb_hdr->bl_data_off = p_ucodehdr[FLCN_NL_UCODE_HDR_OS_DATA_OFF_IND];
	lsb_hdr->bl_data_size = p_ucodehdr[FLCN_NL_UCODE_HDR_OS_DATA_SIZE_IND];
	return 0;
}

/*!
 * @brief lsfm_fill_static_lsb_hdr_info
 * Populate static LSB header infomation using the provided ucode image
 */
void lsfm_fill_static_lsb_hdr_info(struct gk20a *g,
	u32 falcon_id, struct lsfm_managed_ucode_img_v2 *pnode)
{

	struct nvgpu_pmu *pmu = &g->pmu;
	u32 full_app_size = 0;
	u32 data = 0;

	if (pnode->ucode_img.lsf_desc)
		memcpy(&pnode->lsb_header.signature, pnode->ucode_img.lsf_desc,
			sizeof(struct lsf_ucode_desc_v1));
	pnode->lsb_header.ucode_size = pnode->ucode_img.data_size;

	/* The remainder of the LSB depends on the loader usage */
	if (pnode->ucode_img.header) {
		/* Does not use a loader */
		pnode->lsb_header.data_size = 0;
		pnode->lsb_header.bl_code_size = 0;
		pnode->lsb_header.bl_data_off = 0;
		pnode->lsb_header.bl_data_size = 0;

		lsfm_parse_no_loader_ucode(pnode->ucode_img.header,
			&(pnode->lsb_header));

		/* Load the first 256 bytes of IMEM. */
		/* Set LOAD_CODE_AT_0 and DMACTL_REQ_CTX.
		True for all method based falcons */
		data = NV_FLCN_ACR_LSF_FLAG_LOAD_CODE_AT_0_TRUE |
			NV_FLCN_ACR_LSF_FLAG_DMACTL_REQ_CTX_TRUE;
		pnode->lsb_header.flags = data;
	} else {
		/* Uses a loader. that is has a desc */
		pnode->lsb_header.data_size = 0;

		/* The loader code size is already aligned (padded) such that
		the code following it is aligned, but the size in the image
		desc is not, bloat it up to be on a 256 byte alignment. */
		pnode->lsb_header.bl_code_size = ALIGN(
			pnode->ucode_img.desc->bootloader_size,
			LSF_BL_CODE_SIZE_ALIGNMENT);
		full_app_size = ALIGN(pnode->ucode_img.desc->app_size,
			LSF_BL_CODE_SIZE_ALIGNMENT) +
			pnode->lsb_header.bl_code_size;
		pnode->lsb_header.ucode_size = ALIGN(
			pnode->ucode_img.desc->app_resident_data_offset,
			LSF_BL_CODE_SIZE_ALIGNMENT) +
			pnode->lsb_header.bl_code_size;
		pnode->lsb_header.data_size = full_app_size -
			pnode->lsb_header.ucode_size;
		/* Though the BL is located at 0th offset of the image, the VA
		is different to make sure that it doesnt collide the actual OS
		VA range */
		pnode->lsb_header.bl_imem_off =
			pnode->ucode_img.desc->bootloader_imem_offset;

		/* TODO: OBJFLCN should export properties using which the below
			flags should be populated.*/
		pnode->lsb_header.flags = 0;

		if (falcon_id == pmu->falcon_id) {
			data = NV_FLCN_ACR_LSF_FLAG_DMACTL_REQ_CTX_TRUE;
			pnode->lsb_header.flags = data;
		}

		if(g->ops.pmu.is_priv_load(falcon_id))
			pnode->lsb_header.flags |=
				NV_FLCN_ACR_LSF_FLAG_FORCE_PRIV_LOAD_TRUE;
	}
}

/* Adds a ucode image to the list of managed ucode images managed. */
int lsfm_add_ucode_img(struct gk20a *g, struct ls_flcn_mgr_v1 *plsfm,
	struct flcn_ucode_img_v1 *ucode_image, u32 falcon_id)
{
	struct lsfm_managed_ucode_img_v2 *pnode;

	pnode = nvgpu_kzalloc(g, sizeof(struct lsfm_managed_ucode_img_v2));
	if (pnode == NULL)
		return -ENOMEM;

	/* Keep a copy of the ucode image info locally */
	memcpy(&pnode->ucode_img, ucode_image, sizeof(struct flcn_ucode_img_v1));

	/* Fill in static WPR header info*/
	pnode->wpr_header.falcon_id = falcon_id;
	pnode->wpr_header.bootstrap_owner = g->bootstrap_owner;
	pnode->wpr_header.status = LSF_IMAGE_STATUS_COPY;

	pnode->wpr_header.lazy_bootstrap =
			g->ops.pmu.is_lazy_bootstrap(falcon_id);

	/*TODO to check if PDB_PROP_FLCN_LAZY_BOOTSTRAP is to be supported by
	Android */
	/* Fill in static LSB header info elsewhere */
	lsfm_fill_static_lsb_hdr_info(g, falcon_id, pnode);
	pnode->wpr_header.bin_version = pnode->lsb_header.signature.version;
	pnode->next = plsfm->ucode_img_list;
	plsfm->ucode_img_list = pnode;
	return 0;
}

/* Free any ucode image structure resources. */
void lsfm_free_ucode_img_res(struct gk20a *g,
				    struct flcn_ucode_img_v1 *p_img)
{
	if (p_img->lsf_desc != NULL) {
		nvgpu_kfree(g, p_img->lsf_desc);
		p_img->lsf_desc = NULL;
	}
}

/* Free any ucode image structure resources. */
void lsfm_free_nonpmu_ucode_img_res(struct gk20a *g,
					   struct flcn_ucode_img_v1 *p_img)
{
	if (p_img->lsf_desc != NULL) {
		nvgpu_kfree(g, p_img->lsf_desc);
		p_img->lsf_desc = NULL;
	}
	if (p_img->desc != NULL) {
		nvgpu_kfree(g, p_img->desc);
		p_img->desc = NULL;
	}
}

void free_acr_resources(struct gk20a *g, struct ls_flcn_mgr_v1 *plsfm)
{
	u32 cnt = plsfm->managed_flcn_cnt;
	struct lsfm_managed_ucode_img_v2 *mg_ucode_img;

	while (cnt) {
		mg_ucode_img = plsfm->ucode_img_list;
		if (mg_ucode_img->ucode_img.lsf_desc->falcon_id ==
				LSF_FALCON_ID_PMU)
			lsfm_free_ucode_img_res(g, &mg_ucode_img->ucode_img);
		else
			lsfm_free_nonpmu_ucode_img_res(g,
				&mg_ucode_img->ucode_img);
		plsfm->ucode_img_list = mg_ucode_img->next;
		nvgpu_kfree(g, mg_ucode_img);
		cnt--;
	}
}

/* Generate WPR requirements for ACR allocation request */
int lsf_gen_wpr_requirements(struct gk20a *g,
		struct ls_flcn_mgr_v1 *plsfm)
{
	struct lsfm_managed_ucode_img_v2 *pnode = plsfm->ucode_img_list;
	u32 wpr_offset;

	/* Calculate WPR size required */

	/* Start with an array of WPR headers at the base of the WPR.
	 The expectation here is that the secure falcon will do a single DMA
	 read of this array and cache it internally so it's OK to pack these.
	 Also, we add 1 to the falcon count to indicate the end of the array.*/
	wpr_offset = sizeof(struct lsf_wpr_header_v1) *
		(plsfm->managed_flcn_cnt+1);

	/* Walk the managed falcons, accounting for the LSB structs
	as well as the ucode images. */
	while (pnode) {
		/* Align, save off, and include an LSB header size */
		wpr_offset = ALIGN(wpr_offset,
			LSF_LSB_HEADER_ALIGNMENT);
		pnode->wpr_header.lsb_offset = wpr_offset;
		wpr_offset += sizeof(struct lsf_lsb_header_v1);

		/* Align, save off, and include the original (static)
		ucode image size */
		wpr_offset = ALIGN(wpr_offset,
			LSF_UCODE_DATA_ALIGNMENT);
		pnode->lsb_header.ucode_off = wpr_offset;
		wpr_offset += pnode->ucode_img.data_size;

		/* For falcons that use a boot loader (BL), we append a loader
		desc structure on the end of the ucode image and consider this
		the boot loader data. The host will then copy the loader desc
		args to this space within the WPR region (before locking down)
		and the HS bin will then copy them to DMEM 0 for the loader. */
		if (!pnode->ucode_img.header) {
			/* Track the size for LSB details filled in later
			 Note that at this point we don't know what kind of i
			boot loader desc, so we just take the size of the
			generic one, which is the largest it will will ever be.
			*/
			/* Align (size bloat) and save off generic
			descriptor size*/
			pnode->lsb_header.bl_data_size = ALIGN(
				sizeof(pnode->bl_gen_desc),
				LSF_BL_DATA_SIZE_ALIGNMENT);

			/*Align, save off, and include the additional BL data*/
			wpr_offset = ALIGN(wpr_offset,
				LSF_BL_DATA_ALIGNMENT);
			pnode->lsb_header.bl_data_off = wpr_offset;
			wpr_offset += pnode->lsb_header.bl_data_size;
		} else {
			/* bl_data_off is already assigned in static
			information. But that is from start of the image */
			pnode->lsb_header.bl_data_off +=
				(wpr_offset - pnode->ucode_img.data_size);
		}

		/* Finally, update ucode surface size to include updates */
		pnode->full_ucode_size = wpr_offset -
			pnode->lsb_header.ucode_off;
		if (pnode->wpr_header.falcon_id != LSF_FALCON_ID_PMU) {
			pnode->lsb_header.app_code_off =
				pnode->lsb_header.bl_code_size;
			pnode->lsb_header.app_code_size =
				pnode->lsb_header.ucode_size -
				pnode->lsb_header.bl_code_size;
			pnode->lsb_header.app_data_off =
				pnode->lsb_header.ucode_size;
			pnode->lsb_header.app_data_size =
				pnode->lsb_header.data_size;
		}
		pnode = pnode->next;
	}
	plsfm->wpr_size = wpr_offset;
	return 0;
}

/*Loads ACR bin to FB mem and bootstraps PMU with bootloader code
 * start and end are addresses of ucode blob in non-WPR region*/
int gp106_bootstrap_hs_flcn(struct gk20a *g)
{
	struct mm_gk20a *mm = &g->mm;
	struct vm_gk20a *vm = mm->pmu.vm;
	int err = 0;
	u64 *acr_dmem;
	u32 img_size_in_bytes = 0;
	u32 status;
	struct acr_desc *acr = &g->acr;
	struct nvgpu_firmware *acr_fw = acr->acr_fw;
	struct flcn_bl_dmem_desc_v1 *bl_dmem_desc = &acr->bl_dmem_desc_v1;
	u32 *acr_ucode_header_t210_load;
	u32 *acr_ucode_data_t210_load;
	struct wpr_carveout_info wpr_inf;

	gp106_dbg_pmu(g, " ");

	if (!acr_fw) {
		/*First time init case*/
		acr_fw = nvgpu_request_firmware(g,
				GM20B_HSBIN_PMU_UCODE_IMAGE,
				NVGPU_REQUEST_FIRMWARE_NO_SOC);
		if (!acr_fw) {
			nvgpu_err(g, "pmu ucode get fail");
			return -ENOENT;
		}
		acr->acr_fw = acr_fw;
		acr->hsbin_hdr = (struct bin_hdr *)acr_fw->data;
		acr->fw_hdr = (struct acr_fw_header *)(acr_fw->data +
				acr->hsbin_hdr->header_offset);
		acr_ucode_data_t210_load = (u32 *)(acr_fw->data +
				acr->hsbin_hdr->data_offset);
		acr_ucode_header_t210_load = (u32 *)(acr_fw->data +
				acr->fw_hdr->hdr_offset);
		img_size_in_bytes = ALIGN((acr->hsbin_hdr->data_size), 256);

		/* Lets patch the signatures first.. */
		if (acr_ucode_patch_sig(g, acr_ucode_data_t210_load,
					(u32 *)(acr_fw->data +
						acr->fw_hdr->sig_prod_offset),
					(u32 *)(acr_fw->data +
						acr->fw_hdr->sig_dbg_offset),
					(u32 *)(acr_fw->data +
						acr->fw_hdr->patch_loc),
					(u32 *)(acr_fw->data +
						acr->fw_hdr->patch_sig)) < 0) {
			nvgpu_err(g, "patch signatures fail");
			err = -1;
			goto err_release_acr_fw;
		}
		err = nvgpu_dma_alloc_map_sys(vm, img_size_in_bytes,
				&acr->acr_ucode);
		if (err) {
			err = -ENOMEM;
			goto err_release_acr_fw;
		}

		g->ops.pmu.get_wpr(g, &wpr_inf);

		acr_dmem = (u64 *)
			&(((u8 *)acr_ucode_data_t210_load)[
					acr_ucode_header_t210_load[2]]);
		acr->acr_dmem_desc_v1 = (struct flcn_acr_desc_v1 *)((u8 *)(
			acr->acr_ucode.cpu_va) + acr_ucode_header_t210_load[2]);
		((struct flcn_acr_desc_v1 *)acr_dmem)->nonwpr_ucode_blob_start =
				wpr_inf.nonwpr_base;
		((struct flcn_acr_desc_v1 *)acr_dmem)->nonwpr_ucode_blob_size =
				wpr_inf.size;
		((struct flcn_acr_desc_v1 *)acr_dmem)->regions.no_regions = 1;
		((struct flcn_acr_desc_v1 *)acr_dmem)->wpr_offset = 0;

		((struct flcn_acr_desc_v1 *)acr_dmem)->wpr_region_id = 1;
		((struct flcn_acr_desc_v1 *)acr_dmem)->regions.region_props[
											0].region_id = 1;
		((struct flcn_acr_desc_v1 *)acr_dmem)->regions.region_props[
			0].start_addr = (wpr_inf.wpr_base ) >> 8;
		((struct flcn_acr_desc_v1 *)acr_dmem)->regions.region_props[
			0].end_addr = ((wpr_inf.wpr_base) + wpr_inf.size) >> 8;
		((struct flcn_acr_desc_v1 *)acr_dmem)->regions.region_props[
			0].shadowmMem_startaddress = wpr_inf.nonwpr_base >> 8;

		nvgpu_mem_wr_n(g, &acr->acr_ucode, 0,
				acr_ucode_data_t210_load, img_size_in_bytes);

		/*
		 * In order to execute this binary, we will be using
		 * a bootloader which will load this image into PMU IMEM/DMEM.
		 * Fill up the bootloader descriptor for PMU HAL to use..
		 * TODO: Use standard descriptor which the generic bootloader is
		 * checked in.
		 */

		bl_dmem_desc->signature[0] = 0;
		bl_dmem_desc->signature[1] = 0;
		bl_dmem_desc->signature[2] = 0;
		bl_dmem_desc->signature[3] = 0;
		bl_dmem_desc->ctx_dma = GK20A_PMU_DMAIDX_VIRT;
		flcn64_set_dma( &bl_dmem_desc->code_dma_base,
						acr->acr_ucode.gpu_va);
		bl_dmem_desc->non_sec_code_off  = acr_ucode_header_t210_load[0];
		bl_dmem_desc->non_sec_code_size = acr_ucode_header_t210_load[1];
		bl_dmem_desc->sec_code_off = acr_ucode_header_t210_load[5];
		bl_dmem_desc->sec_code_size = acr_ucode_header_t210_load[6];
		bl_dmem_desc->code_entry_point = 0; /* Start at 0th offset */
		flcn64_set_dma( &bl_dmem_desc->data_dma_base,
					acr->acr_ucode.gpu_va +
					(acr_ucode_header_t210_load[2]));
		bl_dmem_desc->data_size = acr_ucode_header_t210_load[3];
	} else
		acr->acr_dmem_desc->nonwpr_ucode_blob_size = 0;

	status = pmu_exec_gen_bl(g, bl_dmem_desc, 1);
	if (status != 0) {
		err = status;
		goto err_free_ucode_map;
	}

	/* sec2 reset - to keep it idle */
	gk20a_writel(g, psec_falcon_engine_r(),
		pwr_falcon_engine_reset_true_f());
	nvgpu_udelay(10);
	gk20a_writel(g, psec_falcon_engine_r(),
		pwr_falcon_engine_reset_false_f());

	return 0;
err_free_ucode_map:
	nvgpu_dma_unmap_free(vm, &acr->acr_ucode);
err_release_acr_fw:
	nvgpu_release_firmware(g, acr_fw);
	acr->acr_fw = NULL;
	return err;
}
