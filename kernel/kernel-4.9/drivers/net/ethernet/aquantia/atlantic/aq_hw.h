/*
 * aQuantia Corporation Network Driver
 * Copyright (C) 2014-2017 aQuantia Corporation. All rights reserved
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms and conditions of the GNU General Public License,
 * version 2, as published by the Free Software Foundation.
 */

/* File aq_hw.h: Declaration of abstract interface for NIC hardware specific
 * functions.
 */

#ifndef AQ_HW_H
#define AQ_HW_H

#include "aq_common.h"
#include "aq_rss.h"
#include "hw_atl/hw_atl_utils.h"

/* NIC H/W capabilities */
struct aq_hw_caps_s {
	u64 hw_features;
	u64 link_speed_msk;
	unsigned int hw_priv_flags;
	u32 media_type;
	u32 rxds;
	u32 txds;
	u32 txhwb_alignment;
	u32 irq_mask;
	u32 vecs;
	u32 mtu;
	u32 mac_regs_count;
	u32 hw_alive_check_addr;
	u8 msix_irqs;
	u8 tcs;
	u8 rxd_alignment;
	u8 rxd_size;
	u8 txd_alignment;
	u8 txd_size;
	u8 tx_rings;
	u8 rx_rings;
	bool flow_control;
	bool is_64_dma;
};

struct aq_hw_link_status_s {
	unsigned int mbps;
};

struct aq_stats_s {
	u64 uprc;
	u64 mprc;
	u64 bprc;
	u64 erpt;
	u64 uptc;
	u64 mptc;
	u64 bptc;
	u64 erpr;
	u64 mbtc;
	u64 bbtc;
	u64 mbrc;
	u64 bbrc;
	u64 ubrc;
	u64 ubtc;
	u64 dpc;
	u64 dma_pkt_rc;
	u64 dma_pkt_tc;
	u64 dma_oct_rc;
	u64 dma_oct_tc;
};

#define AQ_HW_IRQ_INVALID 0U
#define AQ_HW_IRQ_LEGACY  1U
#define AQ_HW_IRQ_MSI     2U
#define AQ_HW_IRQ_MSIX    3U

#define AQ_HW_POWER_STATE_D0   0U
#define AQ_HW_POWER_STATE_D3   3U

#define AQ_HW_FLAG_STARTED     0x00000004U
#define AQ_HW_FLAG_STOPPING    0x00000008U
#define AQ_HW_FLAG_RESETTING   0x00000010U
#define AQ_HW_FLAG_CLOSING     0x00000020U
#define AQ_HW_LINK_DOWN        0x04000000U
#define AQ_HW_FLAG_ERR_UNPLUG  0x40000000U
#define AQ_HW_FLAG_ERR_HW      0x80000000U

#define AQ_HW_FLAG_ERRORS      (AQ_HW_FLAG_ERR_HW | AQ_HW_FLAG_ERR_UNPLUG)

#define AQ_NIC_FLAGS_IS_NOT_READY (AQ_NIC_FLAG_STOPPING | \
			AQ_NIC_FLAG_RESETTING | AQ_NIC_FLAG_CLOSING | \
			AQ_NIC_FLAG_ERR_UNPLUG | AQ_NIC_FLAG_ERR_HW)

#define AQ_NIC_FLAGS_IS_NOT_TX_READY (AQ_NIC_FLAGS_IS_NOT_READY | \
					AQ_NIC_LINK_DOWN)

#define AQ_HW_MEDIA_TYPE_TP    1U
#define AQ_HW_MEDIA_TYPE_FIBRE 2U

struct aq_hw_s {
	atomic_t flags;
	u8 rbl_enabled:1;
	struct aq_nic_cfg_s *aq_nic_cfg;
	const struct aq_fw_ops *aq_fw_ops;
	void __iomem *mmio;
	struct aq_hw_link_status_s aq_link_status;
	struct hw_aq_atl_utils_mbox mbox;
	struct hw_atl_stats_s last_stats;
	struct aq_stats_s curr_stats;

	u64 speed;
	u32 itr_tx;
	u32 itr_rx;
	unsigned int chip_features;
	u32 fw_ver_actual;
	atomic_t dpc;
	u32 mbox_addr;
	u32 rpc_addr;
	u32 rpc_tid;
	struct hw_aq_atl_utils_fw_rpc rpc;
};

struct aq_ring_s;
struct aq_ring_param_s;
struct sk_buff;

struct aq_hw_ops {

	int (*hw_ring_tx_xmit)(struct aq_hw_s *self, struct aq_ring_s *aq_ring,
			       unsigned int frags);

	int (*hw_ring_rx_receive)(struct aq_hw_s *self,
				  struct aq_ring_s *aq_ring);

	int (*hw_ring_rx_fill)(struct aq_hw_s *self, struct aq_ring_s *aq_ring,
			       unsigned int sw_tail_old);

	int (*hw_ring_tx_head_update)(struct aq_hw_s *self,
				      struct aq_ring_s *aq_ring);

	int (*hw_set_mac_address)(struct aq_hw_s *self, u8 *mac_addr);

	int (*hw_reset)(struct aq_hw_s *self);

	int (*hw_init)(struct aq_hw_s *self, u8 *mac_addr);

	int (*hw_start)(struct aq_hw_s *self);

	int (*hw_stop)(struct aq_hw_s *self);
	
	int (*hw_tx_tc_mode_get)(struct aq_hw_s *self, u32 *tc_mode);
	
	int (*hw_rx_tc_mode_get)(struct aq_hw_s *self, u32 *tc_mode);

	int (*hw_ring_tx_init)(struct aq_hw_s *self, struct aq_ring_s *aq_ring,
			       struct aq_ring_param_s *aq_ring_param);

	int (*hw_ring_tx_start)(struct aq_hw_s *self,
				struct aq_ring_s *aq_ring);

	int (*hw_ring_tx_stop)(struct aq_hw_s *self,
			       struct aq_ring_s *aq_ring);

	int (*hw_ring_rx_init)(struct aq_hw_s *self,
			       struct aq_ring_s *aq_ring,
			       struct aq_ring_param_s *aq_ring_param);

	int (*hw_ring_rx_start)(struct aq_hw_s *self,
				struct aq_ring_s *aq_ring);

	int (*hw_ring_rx_stop)(struct aq_hw_s *self,
			       struct aq_ring_s *aq_ring);
				   
	int (*hw_ring_hwts_rx_fill)(struct aq_hw_s *self, struct aq_ring_s *aq_ring);

	int (*hw_ring_hwts_rx_receive)(struct aq_hw_s *self, struct aq_ring_s *ring);

	int (*hw_irq_enable)(struct aq_hw_s *self, u64 mask);

	int (*hw_irq_disable)(struct aq_hw_s *self, u64 mask);

	int (*hw_irq_read)(struct aq_hw_s *self, u64 *mask);

	int (*hw_packet_filter_set)(struct aq_hw_s *self,
				    unsigned int packet_filter);

	int (*hw_multicast_list_set)(struct aq_hw_s *self,
				     u8 ar_mac[AQ_CFG_MULTICAST_ADDRESS_MAX]
				     [ETH_ALEN],
				     u32 count);
					 
	int (*hw_rx_l3l4_udp_filter_set)(struct aq_hw_s *self, unsigned int num_filter, u16 udp_port);
	
  int (*hw_rx_ethtype_filter_set)(struct aq_hw_s *self, unsigned int num_filter, u16 ethtype);

	int (*hw_interrupt_moderation_set)(struct aq_hw_s *self);

	int (*hw_rss_set)(struct aq_hw_s *self,
			  struct aq_rss_parameters *rss_params);

	int (*hw_rss_hash_set)(struct aq_hw_s *self,
			       struct aq_rss_parameters *rss_params);

	int (*hw_get_regs)(struct aq_hw_s *self,
			   const struct aq_hw_caps_s *aq_hw_caps,
			   u32 *regs_buff);

	struct aq_stats_s *(*hw_get_hw_stats)(struct aq_hw_s *self);

	int (*hw_get_fw_version)(struct aq_hw_s *self, u32 *fw_version);

	
	int (*hw_get_ptp_ts)(struct aq_hw_s *self, u64 *stamp);

	int (*hw_adj_sys_clock)(struct aq_hw_s *self, s32 delta);

	int (*hw_gpio_pulse)(struct aq_hw_s *self, unsigned int index, u32 period);
};

struct aq_fw_ops {
	int (*init)(struct aq_hw_s *self);

	int (*deinit)(struct aq_hw_s *self);

	int (*reset)(struct aq_hw_s *self);

	int (*get_mac_permanent)(struct aq_hw_s *self, u8 *mac);

	int (*set_link_speed)(struct aq_hw_s *self, u32 speed);

	int (*set_state)(struct aq_hw_s *self,
			enum hal_atl_utils_fw_state_e state);

	int (*update_link_status)(struct aq_hw_s *self);

	int (*update_stats)(struct aq_hw_s *self);

	int (*set_power)(struct aq_hw_s *self, unsigned int power_state,
			u8 *mac);

	int (*get_temp)(struct aq_hw_s *self, int *temp);

	int (*get_cable_len)(struct aq_hw_s *self, int *cable_len);
};

#endif /* AQ_HW_H */
