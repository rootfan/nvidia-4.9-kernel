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

#include "gk20a/gk20a.h"

#include "therm_gp106.h"
#include "therm/thrmpmu.h"

#ifdef CONFIG_DEBUG_FS
#include <linux/debugfs.h>
#include "common/linux/os_linux.h"
#endif

#include <nvgpu/hw/gp106/hw_therm_gp106.h>

void gp106_get_internal_sensor_limits(s32 *max_24_8, s32 *min_24_8)
{
	*max_24_8 = (0x87 << 8);
	*min_24_8 = (((u32)-216) << 8);
}

int gp106_get_internal_sensor_curr_temp(struct gk20a *g, u32 *temp_f24_8)
{
	int err = 0;
	u32 readval;

	readval = gk20a_readl(g, therm_temp_sensor_tsense_r());

	if (!(therm_temp_sensor_tsense_state_v(readval) &
		therm_temp_sensor_tsense_state_valid_v())) {
		nvgpu_err(g,
			"Attempt to read temperature while sensor is OFF!");
		err = -EINVAL;
	} else if (therm_temp_sensor_tsense_state_v(readval) &
		therm_temp_sensor_tsense_state_shadow_v()) {
		nvgpu_err(g, "Reading temperature from SHADOWed sensor!");
	}

	// Convert from F9.5 -> F27.5 -> F24.8.
	readval &= therm_temp_sensor_tsense_fixed_point_m();

	*temp_f24_8 = readval;

	return err;
}

#ifdef CONFIG_DEBUG_FS
static int therm_get_internal_sensor_curr_temp(void *data, u64 *val)
{
	struct gk20a *g = (struct gk20a *)data;
	u32 readval;
	int err;

	err = gp106_get_internal_sensor_curr_temp(g, &readval);
	if (!err)
		*val = readval;

	return err;
}
DEFINE_SIMPLE_ATTRIBUTE(therm_ctrl_fops, therm_get_internal_sensor_curr_temp, NULL, "%llu\n");

void gp106_therm_debugfs_init(struct gk20a *g)
{
	struct nvgpu_os_linux *l = nvgpu_os_linux_from_gk20a(g);
	struct dentry *dbgentry;

	dbgentry = debugfs_create_file(
		"temp", S_IRUGO, l->debugfs, g, &therm_ctrl_fops);
	if (!dbgentry)
		nvgpu_err(g, "debugfs entry create failed for therm_curr_temp");
}
#endif

int gp106_elcg_init_idle_filters(struct gk20a *g)
{
	u32 gate_ctrl, idle_filter;
	u32 engine_id;
	u32 active_engine_id = 0;
	struct fifo_gk20a *f = &g->fifo;

	nvgpu_log_fn(g, " ");

	for (engine_id = 0; engine_id < f->num_engines; engine_id++) {
		active_engine_id = f->active_engines_list[engine_id];
		gate_ctrl = gk20a_readl(g, therm_gate_ctrl_r(active_engine_id));

		gate_ctrl = set_field(gate_ctrl,
			therm_gate_ctrl_eng_idle_filt_exp_m(),
			therm_gate_ctrl_eng_idle_filt_exp_f(2));
		gate_ctrl = set_field(gate_ctrl,
			therm_gate_ctrl_eng_idle_filt_mant_m(),
			therm_gate_ctrl_eng_idle_filt_mant_f(1));
		gate_ctrl = set_field(gate_ctrl,
			therm_gate_ctrl_eng_delay_before_m(),
			therm_gate_ctrl_eng_delay_before_f(0));
		gk20a_writel(g, therm_gate_ctrl_r(active_engine_id), gate_ctrl);
	}

	/* default fecs_idle_filter to 0 */
	idle_filter = gk20a_readl(g, therm_fecs_idle_filter_r());
	idle_filter &= ~therm_fecs_idle_filter_value_m();
	gk20a_writel(g, therm_fecs_idle_filter_r(), idle_filter);
	/* default hubmmu_idle_filter to 0 */
	idle_filter = gk20a_readl(g, therm_hubmmu_idle_filter_r());
	idle_filter &= ~therm_hubmmu_idle_filter_value_m();
	gk20a_writel(g, therm_hubmmu_idle_filter_r(), idle_filter);

	nvgpu_log_fn(g, "done");
	return 0;
}

u32 gp106_configure_therm_alert(struct gk20a *g, s32 curr_warn_temp)
{
	u32 err = 0;

	if (g->curr_warn_temp != curr_warn_temp) {
		g->curr_warn_temp = curr_warn_temp;
		err = therm_configure_therm_alert(g);
	}

	return err;
}
