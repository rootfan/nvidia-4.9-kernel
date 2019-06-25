/*
 * tegra210_dmic_alt.h - Definitions for Tegra210 DMIC driver
 *
 * Copyright (c) 2014-2018 NVIDIA CORPORATION.  All rights reserved.
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

#ifndef __TEGRA210_DMIC_ALT_H__
#define __TEGRA210_DMIC_ALT_H__

/* Register offsets from DMIC BASE */
#define TEGRA210_DMIC_TX_STATUS				0x0c
#define TEGRA210_DMIC_TX_INT_STATUS			0x10
#define TEGRA210_DMIC_TX_INT_MASK			0x14
#define TEGRA210_DMIC_TX_INT_SET			0x18
#define TEGRA210_DMIC_TX_INT_CLEAR			0x1c
#define TEGRA210_DMIC_TX_CIF_CTRL			0x20

#define TEGRA210_DMIC_ENABLE				0x40
#define TEGRA210_DMIC_SOFT_RESET			0x44
#define TEGRA210_DMIC_CG				0x48
#define TEGRA210_DMIC_STATUS				0x4c
#define TEGRA210_DMIC_INT_STATUS			0x50
#define TEGRA210_DMIC_CTRL				0x64

#define TEGRA210_DMIC_DBG_CTRL				0x70
#define TEGRA210_DMIC_DCR_FILTER_GAIN			0x74
#define TEGRA210_DMIC_DCR_BIQUAD_0_COEF_0		0x78
#define TEGRA210_DMIC_DCR_BIQUAD_0_COEF_1		0x7c
#define TEGRA210_DMIC_DCR_BIQUAD_0_COEF_2		0x80
#define TEGRA210_DMIC_DCR_BIQUAD_0_COEF_3		0x84
#define TEGRA210_DMIC_DCR_BIQUAD_0_COEF_4		0x88
#define TEGRA210_DMIC_LP_FILTER_GAIN			0x8c
#define TEGRA210_DMIC_LP_BIQUAD_0_COEF_0		0x90
#define TEGRA210_DMIC_LP_BIQUAD_0_COEF_1		0x94
#define TEGRA210_DMIC_LP_BIQUAD_0_COEF_2		0x98
#define TEGRA210_DMIC_LP_BIQUAD_0_COEF_3		0x9c
#define TEGRA210_DMIC_LP_BIQUAD_0_COEF_4		0xa0
#define TEGRA210_DMIC_LP_BIQUAD_1_COEF_0		0xa4
#define TEGRA210_DMIC_LP_BIQUAD_1_COEF_1		0xa8
#define TEGRA210_DMIC_LP_BIQUAD_1_COEF_2		0xac
#define TEGRA210_DMIC_LP_BIQUAD_1_COEF_3		0xb0
#define TEGRA210_DMIC_LP_BIQUAD_1_COEF_4		0xb4
#define TEGRA210_DMIC_CORRECTION_FILTER_GAIN		0xb8
#define TEGRA210_DMIC_CORRECTION_BIQUAD_0_COEF_0	0xbc
#define TEGRA210_DMIC_CORRECTION_BIQUAD_0_COEF_1	0xc0
#define TEGRA210_DMIC_CORRECTION_BIQUAD_0_COEF_2	0xc4
#define TEGRA210_DMIC_CORRECTION_BIQUAD_0_COEF_3	0xc8
#define TEGRA210_DMIC_CORRECTION_BIQUAD_0_COEF_4	0xcc
#define TEGRA210_DMIC_CORRECTION_BIQUAD_1_COEF_0	0xd0
#define TEGRA210_DMIC_CORRECTION_BIQUAD_1_COEF_1	0xd4
#define TEGRA210_DMIC_CORRECTION_BIQUAD_1_COEF_2	0xd8
#define TEGRA210_DMIC_CORRECTION_BIQUAD_1_COEF_3	0xdc
#define TEGRA210_DMIC_CORRECTION_BIQUAD_1_COEF_4	0xe0

/* Constants for DMIC */
#define TEGRA210_DMIC_OSR_64				0
#define TEGRA210_DMIC_OSR_128				1
#define TEGRA210_DMIC_OSR_256				2

/* Fields in TEGRA210_DMIC_ENABLE */
#define TEGRA210_DMIC_ENABLE_EN_SHIFT			0
#define TEGRA210_DMIC_ENABLE_EN				BIT(0)

/* Fields in TEGRA210_DMIC_SOFT_RESET */
#define TEGRA210_DMIC_SOFT_RESET_EN			BIT(0)

/* Fields in TEGRA210_DMIC_CG */
#define TEGRA210_DMIC_CG_SLCG_EN			BIT(0)

/* Fields in TEGRA210_DMIC_STATUS */
#define TEGRA210_DMIC_STATUS_CONFIG_ERROR_SHIFT		31
#define TEGRA210_DMIC_STATUS_CONFIG_ERROR_MASK		(0x1 << TEGRA210_DMIC_STATUS_CONFIG_ERROR_SHIFT)

#define TEGRA210_DMIC_STATUS_SLCG_CLKEN_SHIFT		8
#define TEGRA210_DMIC_STATUS_SLCG_CLKEN_MASK		(0x1 << TEGRA210_DMIC_STATUS_SLCG_CLKEN_SHIFT)

#define TEGRA210_DMIC_STATUS_ENABLE_STATUS_SHIFT	0
#define TEGRA210_DMIC_STATUS_ENABLE_STATUS_MASK		(0x1 << TEGRA210_DMIC_STATUS_ENABLE_STATUS_SHIFT)

/* Fields in TEGRA210_DMIC_CTRL */
#define TEGRA210_DMIC_CTRL_TRIMMER_SEL_SHIFT		12
#define TEGRA210_DMIC_CTRL_TRIMMER_SEL_MASK		(0x1f << TEGRA210_DMIC_CTRL_TRIMMER_SEL_SHIFT)

#define TEGRA210_DMIC_CTRL_CHANNEL_SELECT_SHIFT		8
#define TEGRA210_DMIC_CTRL_CHANNEL_SELECT_MASK		(0x3 << TEGRA210_DMIC_CTRL_CHANNEL_SELECT_SHIFT)

#define TEGRA210_DMIC_CTRL_LRSEL_POLARITY_SHIFT		4
#define TEGRA210_DMIC_CTRL_LRSEL_POLARITY_MASK		(0x1 << TEGRA210_DMIC_CTRL_LRSEL_POLARITY_SHIFT)

#define TEGRA210_DMIC_CTRL_OSR_SHIFT			0
#define TEGRA210_DMIC_CTRL_OSR_MASK			(0x3 << TEGRA210_DMIC_CTRL_OSR_SHIFT)

/* Fields in TEGRA210_DMIC_DBG_CTRL */
#define TEGRA210_DMIC_DBG_CTRL_DCR_ENABLE		BIT(3)
#define TEGRA210_DMIC_DBG_CTRL_LP_ENABLE		BIT(2)
#define TEGRA210_DMIC_DBG_CTRL_SC_ENABLE		BIT(1)
#define TEGRA210_DMIC_DBG_CTRL_BYPASS			BIT(0)

enum tegra_dmic_ch_select {
	DMIC_CH_SELECT_NONE,
	DMIC_CH_SELECT_LEFT,
	DMIC_CH_SELECT_RIGHT,
	DMIC_CH_SELECT_STEREO,
};
struct tegra210_dmic_soc_data {
	void (*set_audio_cif)(struct regmap *map,
			unsigned int reg,
			struct tegra210_xbar_cif_conf *conf);
};

struct tegra210_dmic {
	struct clk *clk_dmic;
	struct clk *clk_pll_a_out0;
	struct regmap *regmap;
	const struct tegra210_dmic_soc_data *soc_data;
	int is_pinctrl;
	struct pinctrl *pinctrl;
	struct pinctrl_state *pin_active_state;
	struct pinctrl_state *pin_idle_state;
	const char *prod_name;
	int boost_gain; /* with 100x factor */
	int ch_select;
	int tx_mono_to_stereo;
	int sample_rate_via_control;
	unsigned int osr_val; /* osr value */
	int lrsel;
	bool is_shutdown;
	int format_out;
	bool set_parent_rate;
	void (*start_capture_cb)(void);
};

/* exported functions to enable DMIC from other driver */
int tegra210_dmic_enable(int id);
int tegra210_dmic_disable(int id);

#endif
