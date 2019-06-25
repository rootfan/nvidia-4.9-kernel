/*
 * tegracam_ctrls - control framework for tegra camera drivers
 *
 * Copyright (c) 2017-2018, NVIDIA CORPORATION.  All rights reserved.
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
#include <linux/types.h>
#include <media/tegra-v4l2-camera.h>
#include <media/camera_common.h>

#define CTRL_U32_MIN 0
#define CTRL_U32_MAX 0x7FFFFFFF
#define CTRL_U64_MIN 0
#define CTRL_U64_MAX 0x7FFFFFFFFFFFFFFFLL
#define CTRL_S32_MIN 0x80000000
#define CTRL_S32_MAX 0x7FFFFFFF
#define CTRL_S64_MIN 0x8000000000000000LL
#define CTRL_S64_MAX 0x7FFFFFFFFFFFFFFFLL
#define CTRL_MAX_STR_SIZE 4096

static int tegracam_s_ctrl(struct v4l2_ctrl *ctrl);
static const struct v4l2_ctrl_ops tegracam_ctrl_ops = {
	.s_ctrl = tegracam_s_ctrl,
};

static struct v4l2_ctrl_config ctrl_cfg_list[] = {
/* Do not change the name field for the controls! */
	{
		.ops = &tegracam_ctrl_ops,
		.id = TEGRA_CAMERA_CID_GAIN,
		.name = "Gain",
		.type = V4L2_CTRL_TYPE_INTEGER64,
		.flags = V4L2_CTRL_FLAG_SLIDER,
		.min = CTRL_U64_MIN,
		.max = CTRL_U64_MAX,
		.def = CTRL_U64_MIN,
		.step = 1,
	},
	{
		.ops = &tegracam_ctrl_ops,
		.id = TEGRA_CAMERA_CID_EXPOSURE,
		.name = "Exposure",
		.type = V4L2_CTRL_TYPE_INTEGER64,
		.flags = V4L2_CTRL_FLAG_SLIDER,
		.min = CTRL_U64_MIN,
		.max = CTRL_U64_MAX,
		.def = CTRL_U64_MIN,
		.step = 1,
	},
	{
		.ops = &tegracam_ctrl_ops,
		.id = TEGRA_CAMERA_CID_FRAME_RATE,
		.name = "Frame Rate",
		.type = V4L2_CTRL_TYPE_INTEGER64,
		.flags = V4L2_CTRL_FLAG_SLIDER,
		.min = CTRL_U64_MIN,
		.max = CTRL_U64_MAX,
		.def = CTRL_U64_MIN,
		.step = 1,
	},
	{
		.ops = &tegracam_ctrl_ops,
		.id = TEGRA_CAMERA_CID_GROUP_HOLD,
		.name = "Group Hold",
		.type = V4L2_CTRL_TYPE_BOOLEAN,
		.min = 0,
		.max = 1,
		.def = 0,
		.step = 1,
	},
	{
		.ops = &tegracam_ctrl_ops,
		.id = TEGRA_CAMERA_CID_EEPROM_DATA,
		.name = "EEPROM Data",
		.type = V4L2_CTRL_TYPE_STRING,
		.flags = V4L2_CTRL_FLAG_READ_ONLY,
		.min = 0,
		.max = CTRL_MAX_STR_SIZE,
		.step = 2,
	},
	{
		.ops = &tegracam_ctrl_ops,
		.id = TEGRA_CAMERA_CID_FUSE_ID,
		.name = "Fuse ID",
		.type = V4L2_CTRL_TYPE_STRING,
		.flags = V4L2_CTRL_FLAG_READ_ONLY,
		.min = 0,
		.max = CTRL_MAX_STR_SIZE,
		.step = 2,
	},
	{
		.ops = &tegracam_ctrl_ops,
		.id = TEGRA_CAMERA_CID_SENSOR_MODE_ID,
		.name = "Sensor Mode",
		.type = V4L2_CTRL_TYPE_INTEGER64,
		.flags = V4L2_CTRL_FLAG_SLIDER,
		.min = CTRL_U32_MIN,
		.max = CTRL_U32_MAX,
		.def = CTRL_U32_MIN,
		.step = 1,
	},
	{
		.ops = &tegracam_ctrl_ops,
		.id = TEGRA_CAMERA_CID_HDR_EN,
		.name = "HDR enable",
		.type = V4L2_CTRL_TYPE_INTEGER_MENU,
		.min = 0,
		.max = ARRAY_SIZE(switch_ctrl_qmenu) - 1,
		.menu_skip_mask = 0,
		.def = 0,
		.qmenu_int = switch_ctrl_qmenu,
	},
};

static int tegracam_get_ctrl_index(u32 cid)
{
	int i;

	for (i = 0; i < ARRAY_SIZE(ctrl_cfg_list); i++) {
		if (ctrl_cfg_list[i].id == cid)
			return i;
	}

	return -EINVAL;
}

static int tegracam_get_string_ctrl_size(u32 cid,
		const struct tegracam_ctrl_ops *ops)
{
	u32 index = 0;

	switch (cid) {
	case TEGRA_CAMERA_CID_EEPROM_DATA:
		index = TEGRA_CAM_STRING_CTRL_EEPROM_INDEX;
		break;
	case TEGRA_CAMERA_CID_FUSE_ID:
		index = TEGRA_CAM_STRING_CTRL_FUSEID_INDEX;
		break;
	case TEGRA_CAMERA_CID_OTP_DATA:
		index = TEGRA_CAM_STRING_CTRL_OTP_INDEX;
		break;
	default:
		return -EINVAL;
	}

	return ops->string_ctrl_size[index];
}

static int tegracam_setup_string_ctrls(struct camera_common_data *s_data,
				struct tegracam_ctrl_handler *handler)
{
	const struct tegracam_ctrl_ops *ops = handler->ctrl_ops;
	u32 numctrls = ops->numctrls;
	int i;
	int err = 0;

	for (i = 0; i < numctrls; i++) {
		struct v4l2_ctrl *ctrl = handler->ctrls[i];

		if (ctrl->type == V4L2_CTRL_TYPE_STRING) {
			err = ops->fill_string_ctrl(s_data, ctrl);
			if (err)
				return err;
		}
	}

	return 0;
}

static int tegracam_s_ctrl(struct v4l2_ctrl *ctrl)
{
	struct tegracam_ctrl_handler *handler =
		container_of(ctrl->handler,
			struct tegracam_ctrl_handler, ctrl_handler);
	const struct tegracam_ctrl_ops *ops = handler->ctrl_ops;
	struct camera_common_data *s_data = handler->s_data;
	int err = 0;
	u32 status = 0;

	if (v4l2_subdev_call(&s_data->subdev, video, g_input_status, &status)) {
		dev_err(s_data->dev, "power status query unsupported\n");
		return -ENOTTY;
	}

	/* power state is turned off, do not program sensor now */
	if (!status)
		return 0;

	switch (ctrl->id) {
	case TEGRA_CAMERA_CID_GAIN:
		err = ops->set_gain(s_data, *ctrl->p_new.p_s64);
		break;
	case TEGRA_CAMERA_CID_FRAME_RATE:
		err = ops->set_frame_rate(s_data, *ctrl->p_new.p_s64);
		break;
	case TEGRA_CAMERA_CID_EXPOSURE:
		err = ops->set_exposure(s_data, *ctrl->p_new.p_s64);
		break;
	case TEGRA_CAMERA_CID_GROUP_HOLD:
		err = ops->set_group_hold(s_data, ctrl->val);
		break;
	case TEGRA_CAMERA_CID_SENSOR_MODE_ID:
		s_data->sensor_mode_id = (int) (*ctrl->p_new.p_s64);
	case TEGRA_CAMERA_CID_HDR_EN:
		break;
	default:
		pr_err("%s: unknown ctrl id.\n", __func__);
		return -EINVAL;
	}

	return err;
}

int tegracam_init_ctrl_ranges_by_mode(
		struct tegracam_ctrl_handler *handler,
		u32 modeidx)
{
	struct camera_common_data *s_data = handler->s_data;
	struct sensor_control_properties *ctrlprops = NULL;
	int i;

	if (modeidx >= s_data->sensor_props.num_modes)
		return -EINVAL;

	ctrlprops =
		&s_data->sensor_props.sensor_modes[modeidx].control_properties;

	for (i = 0; i < handler->numctrls; i++) {
		struct v4l2_ctrl *ctrl = handler->ctrls[i];
		int err = 0;

		switch (ctrl->id) {
		case TEGRA_CAMERA_CID_GAIN:
			err = v4l2_ctrl_modify_range(ctrl,
				ctrlprops->min_gain_val,
				ctrlprops->max_gain_val,
				ctrlprops->step_gain_val,
				ctrlprops->min_gain_val);
			break;
		case TEGRA_CAMERA_CID_FRAME_RATE:
			err = v4l2_ctrl_modify_range(ctrl,
				ctrlprops->min_framerate,
				ctrlprops->max_framerate,
				ctrlprops->step_framerate,
				ctrlprops->max_framerate);
			break;
		case TEGRA_CAMERA_CID_EXPOSURE:
			err = v4l2_ctrl_modify_range(ctrl,
				ctrlprops->min_exp_time.val,
				ctrlprops->max_exp_time.val,
				ctrlprops->step_exp_time.val,
				ctrlprops->max_exp_time.val);
			break;
		default:
			/* Not required to modify these control ranges */
			break;
		}

		if (err) {
			dev_err(s_data->dev,
				"ctrl %s range update failed\n", ctrl->name);
			return err;
		}
	}

	return 0;
}
EXPORT_SYMBOL_GPL(tegracam_init_ctrl_ranges_by_mode);

int tegracam_ctrl_handler_init(struct tegracam_ctrl_handler *handler)
{
	struct camera_common_data *s_data = handler->s_data;
	struct v4l2_ctrl *ctrl;
	struct v4l2_ctrl_config *ctrl_cfg;
	struct device *dev = s_data->dev;
	const struct tegracam_ctrl_ops *ops = handler->ctrl_ops;
	const u32 *cids = ops->ctrl_cid_list;
	u32 numctrls = ops->numctrls;
	int i;
	int err = 0;

	v4l2_ctrl_handler_init(&handler->ctrl_handler, numctrls);

	for (i = 0; i < numctrls; i++) {
		int index = tegracam_get_ctrl_index(cids[i]);
		int size = 0;

		if (index >= ARRAY_SIZE(ctrl_cfg_list)) {
			dev_err(dev, "unsupported control in the list\n");
			return -ENOTTY;
		}

		ctrl_cfg = &ctrl_cfg_list[index];
		if (ctrl_cfg->type == V4L2_CTRL_TYPE_STRING) {
			size = tegracam_get_string_ctrl_size(ctrl_cfg->id, ops);
			if (size < 0) {
				dev_err(dev, "Invalid string ctrl size\n");
				return -EINVAL;
			}
			ctrl_cfg->max = size;
		}

		ctrl = v4l2_ctrl_new_custom(&handler->ctrl_handler,
			ctrl_cfg, NULL);
		if (ctrl == NULL) {
			dev_err(dev, "Failed to init %s ctrl\n",
				ctrl_cfg->name);
			return -EINVAL;
		}

		if (ctrl_cfg->type == V4L2_CTRL_TYPE_STRING &&
			ctrl_cfg->flags & V4L2_CTRL_FLAG_READ_ONLY) {
			ctrl->p_new.p_char = devm_kzalloc(s_data->dev,
				size + 1, GFP_KERNEL);
		}
		handler->ctrls[i] = ctrl;
	};

	handler->numctrls = numctrls;
	err = v4l2_ctrl_handler_setup(&handler->ctrl_handler);
	if (err) {
		dev_err(dev, "Error %d in control hdl setup\n", err);
		goto error;
	}

	err = handler->ctrl_handler.error;
	if (err) {
		dev_err(dev, "Error %d adding controls\n", err);
		goto error;
	}

	err = tegracam_setup_string_ctrls(s_data, handler);
	if (err) {
		dev_err(dev, "setup string controls failed\n");
		goto error;
	}

	err = tegracam_init_ctrl_ranges_by_mode(handler,
				s_data->mode_prop_idx);
	if (err) {
		dev_err(dev, "Error %d updating control ranges\n", err);
		goto error;
	}

	return 0;
error:
	v4l2_ctrl_handler_free(&handler->ctrl_handler);
	return err;
}
EXPORT_SYMBOL_GPL(tegracam_ctrl_handler_init);
