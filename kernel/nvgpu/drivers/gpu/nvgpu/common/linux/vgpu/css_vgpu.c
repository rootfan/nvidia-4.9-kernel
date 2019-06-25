/*
 * Copyright (c) 2016-2018, NVIDIA CORPORATION.  All rights reserved.
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms and conditions of the GNU General Public License,
 * version 2, as published by the Free Software Foundation.
 *
 * This program is distributed in the hope it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
 * more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */
#if defined(CONFIG_GK20A_CYCLE_STATS)

#include <nvgpu/vgpu/vgpu_ivm.h>
#include <nvgpu/vgpu/tegra_vgpu.h>
#include <uapi/linux/nvgpu.h>
#include <nvgpu/vgpu/vgpu.h>

#include "gk20a/gk20a.h"
#include "gk20a/channel_gk20a.h"
#include "gk20a/css_gr_gk20a.h"
#include "common/linux/platform_gk20a.h"
#include "common/linux/os_linux.h"
#include "vgpu/css_vgpu.h"

static struct tegra_hv_ivm_cookie *css_cookie;

static struct tegra_hv_ivm_cookie *vgpu_css_reserve_mempool(struct gk20a *g)
{
	struct device *dev = dev_from_gk20a(g);
	struct device_node *np = dev->of_node;
	struct of_phandle_args args;
	struct tegra_hv_ivm_cookie *cookie;
	u32 mempool;
	int err;

	err = of_parse_phandle_with_fixed_args(np,
			"mempool-css", 1, 0, &args);
	if (err) {
		nvgpu_err(g, "dt missing mempool-css");
		return ERR_PTR(err);
	}

	mempool = args.args[0];
	cookie = vgpu_ivm_mempool_reserve(mempool);
	if (IS_ERR_OR_NULL(cookie)) {
		nvgpu_err(g, "mempool  %u reserve failed", mempool);
		return ERR_PTR(-EINVAL);
	}
	return cookie;
}

u32 vgpu_css_get_buffer_size(struct gk20a *g)
{
	struct tegra_hv_ivm_cookie *cookie;
	u32 size;

	nvgpu_log_fn(g, " ");

	if (css_cookie) {
		size = (u32)vgpu_ivm_get_size(css_cookie);
		nvgpu_log_info(g, "buffer size = 0x%08x", size);
		return size;
	}

	cookie = vgpu_css_reserve_mempool(g);
	if (IS_ERR(cookie))
		return 0;

	size = vgpu_ivm_get_size(cookie);

	vgpu_ivm_mempool_unreserve(cookie);
	nvgpu_log_info(g, "buffer size = 0x%08x", size);
	return size;
}

static int vgpu_css_init_snapshot_buffer(struct gr_gk20a *gr)
{
	struct gk20a *g = gr->g;
	struct gk20a_cs_snapshot *data = gr->cs_data;
	void *buf = NULL;
	int err;
	u64 size;

	nvgpu_log_fn(g, " ");

	if (data->hw_snapshot)
		return 0;

	css_cookie = vgpu_css_reserve_mempool(g);
	if (IS_ERR(css_cookie))
		return PTR_ERR(css_cookie);

	size = vgpu_ivm_get_size(css_cookie);
	/* Make sure buffer size is large enough */
	if (size < CSS_MIN_HW_SNAPSHOT_SIZE) {
		nvgpu_info(g, "mempool size 0x%llx too small", size);
		err = -ENOMEM;
		goto fail;
	}

	buf = ioremap_cache(vgpu_ivm_get_ipa(css_cookie), size);
	if (!buf) {
		nvgpu_info(g, "ioremap_cache failed");
		err = -EINVAL;
		goto fail;
	}

	data->hw_snapshot = buf;
	data->hw_end = data->hw_snapshot +
		size / sizeof(struct gk20a_cs_snapshot_fifo_entry);
	data->hw_get = data->hw_snapshot;
	memset(data->hw_snapshot, 0xff, size);
	return 0;
fail:
	vgpu_ivm_mempool_unreserve(css_cookie);
	css_cookie = NULL;
	return err;
}

void vgpu_css_release_snapshot_buffer(struct gr_gk20a *gr)
{
	struct gk20a_cs_snapshot *data = gr->cs_data;
	struct gk20a *g = gr->g;

	if (!data->hw_snapshot)
		return;

	iounmap(data->hw_snapshot);
	data->hw_snapshot = NULL;

	vgpu_ivm_mempool_unreserve(css_cookie);
	css_cookie = NULL;

	nvgpu_log_info(g, "cyclestats(vgpu): buffer for snapshots released\n");
}

int vgpu_css_flush_snapshots(struct channel_gk20a *ch,
			u32 *pending, bool *hw_overflow)
{
	struct gk20a *g = ch->g;
	struct tegra_vgpu_cmd_msg msg = {};
	struct tegra_vgpu_channel_cyclestats_snapshot_params *p;
	struct gr_gk20a *gr = &g->gr;
	struct gk20a_cs_snapshot *data = gr->cs_data;
	int err;

	nvgpu_log_fn(g, " ");

	msg.cmd = TEGRA_VGPU_CMD_CHANNEL_CYCLESTATS_SNAPSHOT;
	msg.handle = vgpu_get_handle(g);
	p = &msg.params.cyclestats_snapshot;
	p->handle = ch->virt_ctx;
	p->subcmd = NVGPU_IOCTL_CHANNEL_CYCLE_STATS_SNAPSHOT_CMD_FLUSH;
	p->buf_info = (uintptr_t)data->hw_get - (uintptr_t)data->hw_snapshot;

	err = vgpu_comm_sendrecv(&msg, sizeof(msg), sizeof(msg));

	err = (err || msg.ret) ? -1 : 0;

	*pending = p->buf_info;
	*hw_overflow = p->hw_overflow;

	return err;
}

static int vgpu_css_attach(struct channel_gk20a *ch,
		struct gk20a_cs_snapshot_client *cs_client)
{
	struct gk20a *g = ch->g;
	struct tegra_vgpu_cmd_msg msg = {};
	struct tegra_vgpu_channel_cyclestats_snapshot_params *p =
				&msg.params.cyclestats_snapshot;
	int err;

	nvgpu_log_fn(g, " ");

	msg.cmd = TEGRA_VGPU_CMD_CHANNEL_CYCLESTATS_SNAPSHOT;
	msg.handle = vgpu_get_handle(g);
	p->handle = ch->virt_ctx;
	p->subcmd = NVGPU_IOCTL_CHANNEL_CYCLE_STATS_SNAPSHOT_CMD_ATTACH;
	p->perfmon_count = cs_client->perfmon_count;

	err = vgpu_comm_sendrecv(&msg, sizeof(msg), sizeof(msg));
	err = err ? err : msg.ret;
	if (err)
		nvgpu_err(g, "failed");
	else
		cs_client->perfmon_start = p->perfmon_start;

	return err;
}

int vgpu_css_detach(struct channel_gk20a *ch,
		struct gk20a_cs_snapshot_client *cs_client)
{
	struct gk20a *g = ch->g;
	struct tegra_vgpu_cmd_msg msg = {};
	struct tegra_vgpu_channel_cyclestats_snapshot_params *p =
				&msg.params.cyclestats_snapshot;
	int err;

	nvgpu_log_fn(g, " ");

	msg.cmd = TEGRA_VGPU_CMD_CHANNEL_CYCLESTATS_SNAPSHOT;
	msg.handle = vgpu_get_handle(g);
	p->handle = ch->virt_ctx;
	p->subcmd = NVGPU_IOCTL_CHANNEL_CYCLE_STATS_SNAPSHOT_CMD_DETACH;
	p->perfmon_start = cs_client->perfmon_start;
	p->perfmon_count = cs_client->perfmon_count;

	err = vgpu_comm_sendrecv(&msg, sizeof(msg), sizeof(msg));
	err = err ? err : msg.ret;
	if (err)
		nvgpu_err(g, "failed");

	return err;
}

int vgpu_css_enable_snapshot_buffer(struct channel_gk20a *ch,
				struct gk20a_cs_snapshot_client *cs_client)
{
	int ret;

	ret = vgpu_css_attach(ch, cs_client);
	if (ret)
		return ret;

	ret = vgpu_css_init_snapshot_buffer(&ch->g->gr);
	return ret;
}
#endif /* CONFIG_GK20A_CYCLE_STATS */
