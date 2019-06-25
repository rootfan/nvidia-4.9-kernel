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

#include <nvgpu/bios.h>
#include <nvgpu/pmuif/nvgpu_gpmu_cmdif.h>

#include "gk20a/gk20a.h"
#include "thrmdev.h"
#include "boardobj/boardobjgrp.h"
#include "boardobj/boardobjgrp_e32.h"
#include "gp106/bios_gp106.h"
#include "ctrl/ctrltherm.h"

static struct boardobj *construct_therm_device(struct gk20a *g,
			void *pargs, u16 pargs_size, u8 type)
{
	struct boardobj *board_obj_ptr = NULL;
	u32 status;

	status = boardobj_construct_super(g, &board_obj_ptr,
		pargs_size, pargs);
	if (status)
		return NULL;

	nvgpu_log_info(g, " Done");

	return board_obj_ptr;
}

static u32 _therm_device_pmudata_instget(struct gk20a *g,
			struct nv_pmu_boardobjgrp *pmuboardobjgrp,
			struct nv_pmu_boardobj **ppboardobjpmudata,
			u8 idx)
{
	struct nv_pmu_therm_therm_device_boardobj_grp_set *pgrp_set =
		(struct nv_pmu_therm_therm_device_boardobj_grp_set *)
		pmuboardobjgrp;

	nvgpu_log_info(g, " ");

	/*check whether pmuboardobjgrp has a valid boardobj in index*/
	if (((u32)BIT(idx) &
			pgrp_set->hdr.data.super.obj_mask.super.data[0]) == 0)
		return -EINVAL;

	*ppboardobjpmudata = (struct nv_pmu_boardobj *)
		&pgrp_set->objects[idx].data;

	nvgpu_log_info(g, " Done");

	return 0;
}

static u32 devinit_get_therm_device_table(struct gk20a *g,
				struct therm_devices *pthermdeviceobjs)
{
	u32 status = 0;
	u8 *therm_device_table_ptr = NULL;
	u8 *curr_therm_device_table_ptr = NULL;
	struct boardobj *boardobj;
	struct therm_device_1x_header therm_device_table_header = { 0 };
	struct therm_device_1x_entry *therm_device_table_entry = NULL;
	u32 index;
	u32 obj_index = 0;
	u16 therm_device_size = 0;
	union {
		struct boardobj boardobj;
		struct therm_device therm_device;
	} therm_device_data;

	nvgpu_log_info(g, " ");

	therm_device_table_ptr = (u8 *)nvgpu_bios_get_perf_table_ptrs(g,
			g->bios.perf_token, THERMAL_DEVICE_TABLE);
	if (therm_device_table_ptr == NULL) {
		status = -EINVAL;
		goto done;
	}

	memcpy(&therm_device_table_header, therm_device_table_ptr,
		VBIOS_THERM_DEVICE_1X_HEADER_SIZE_04);

	if (therm_device_table_header.version !=
			VBIOS_THERM_DEVICE_VERSION_1X) {
		status = -EINVAL;
		goto done;
	}

	if (therm_device_table_header.header_size <
			VBIOS_THERM_DEVICE_1X_HEADER_SIZE_04) {
		status = -EINVAL;
		goto done;
	}

	curr_therm_device_table_ptr = (therm_device_table_ptr +
		VBIOS_THERM_DEVICE_1X_HEADER_SIZE_04);

	for (index = 0; index < therm_device_table_header.num_table_entries;
		index++) {
		therm_device_table_entry = (struct therm_device_1x_entry *)
			(curr_therm_device_table_ptr +
				(therm_device_table_header.table_entry_size * index));

		if (therm_device_table_entry->class_id !=
				NV_VBIOS_THERM_DEVICE_1X_ENTRY_CLASS_GPU) {
			continue;
		}

		therm_device_size = sizeof(struct therm_device);
		therm_device_data.boardobj.type = CTRL_THERMAL_THERM_DEVICE_CLASS_GPU;

		boardobj = construct_therm_device(g, &therm_device_data,
					therm_device_size, therm_device_data.boardobj.type);

		if (!boardobj) {
			nvgpu_err(g,
				"unable to create thermal device for %d type %d",
				index, therm_device_data.boardobj.type);
			status = -EINVAL;
			goto done;
		}

		status = boardobjgrp_objinsert(&pthermdeviceobjs->super.super,
				boardobj, obj_index);

		if (status) {
			nvgpu_err(g,
			"unable to insert thermal device boardobj for %d", index);
			status = -EINVAL;
			goto done;
		}

		++obj_index;
	}

done:
	nvgpu_log_info(g, " done status %x", status);
	return status;
}

u32 therm_device_sw_setup(struct gk20a *g)
{
	u32 status;
	struct boardobjgrp *pboardobjgrp = NULL;
	struct therm_devices *pthermdeviceobjs;

	/* Construct the Super Class and override the Interfaces */
	status = boardobjgrpconstruct_e32(g,
			&g->therm_pmu.therm_deviceobjs.super);
	if (status) {
		nvgpu_err(g,
			  "error creating boardobjgrp for therm devices, status - 0x%x",
			  status);
		goto done;
	}

	pboardobjgrp = &g->therm_pmu.therm_deviceobjs.super.super;
	pthermdeviceobjs = &(g->therm_pmu.therm_deviceobjs);

	/* Override the Interfaces */
	pboardobjgrp->pmudatainstget = _therm_device_pmudata_instget;

	status = devinit_get_therm_device_table(g, pthermdeviceobjs);
	if (status)
		goto done;

	BOARDOBJGRP_PMU_CONSTRUCT(pboardobjgrp, THERM, THERM_DEVICE);

	status = BOARDOBJGRP_PMU_CMD_GRP_SET_CONSTRUCT(g, pboardobjgrp,
			therm, THERM, therm_device, THERM_DEVICE);
	if (status) {
		nvgpu_err(g,
			  "error constructing PMU_BOARDOBJ_CMD_GRP_SET interface - 0x%x",
			  status);
		goto done;
	}

done:
	nvgpu_log_info(g, " done status %x", status);
	return status;
}
