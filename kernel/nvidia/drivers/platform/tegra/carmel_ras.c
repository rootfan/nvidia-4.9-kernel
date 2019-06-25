/*
 * RAS driver for T194
 *
 * Copyright (c) 2018, NVIDIA CORPORATION.  All rights reserved.
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms and conditions of the GNU General Public License,
 * version 2, as published by the Free Software Foundation.
 *
 * This program is distributed in the hope it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
 * more details.
 */

#include <linux/module.h>
#include <asm/traps.h>
#include <linux/platform/tegra/tegra18_cpu_map.h>
#include <linux/platform/tegra/carmel_ras.h>
#include <linux/platform/tegra/tegra-cpu.h>
#include <linux/of_device.h>
#include <linux/debugfs.h>
#include <linux/cpuhotplug.h>

static LIST_HEAD(core_ras_list);
static DEFINE_RAW_SPINLOCK(core_ras_lock);
static LIST_HEAD(corecluster_ras_list);
static DEFINE_RAW_SPINLOCK(corecluster_ras_lock);
static LIST_HEAD(ccplex_ras_list);
static DEFINE_RAW_SPINLOCK(ccplex_ras_lock);

static struct dentry *debugfs_dir;
static struct dentry *debugfs_node;
static int is_debug;

/* saved hotplug state */
static enum cpuhp_state hp_state;

/* Error Records per CORE - IFU errors
 * error_code = value of ARM_ERR_STATUS:IERR[15:8]
 */
static struct ras_error ifu_errors[] = {
	{.name = "Mitigation Parity Error", .error_code = 0x12},
	{.name = "IMQ Data Parity", .error_code = 0x01},
	{.name = "L2 I$ Fetch Uncorrectable", .error_code = 0x02},
	{.name = "I$ Tag Parity Snoop", .error_code = 0x03},
	{.name = "I$ Multi-Hit Snoop", .error_code = 0x04},
	{.name = "ITLB Parity", .error_code = 0x05},
	{.name = "Trace Hash Error", .error_code = 0x06},
	{.name = "I$ Data Parity", .error_code = 0x07},
	{.name = "I$ Tag Parity", .error_code = 0x10},
	{.name = "I$ Multi-Hit", .error_code = 0x11},
	{}
};

/* Error Records per CORE - RET JSR errors */
static struct ras_error ret_jsr_errors[] = {
	{.name = "Garbage Budle", .error_code = 0x19},
	{.name = "FRF Parity", .error_code = 0x1B},
	{.name = "IRF Parity", .error_code = 0x1A},
	{.name = "RET Timeout", .error_code = 0x18},
	{}
};

/* Error Records per CORE - MTS JSR errors */
static struct ras_error mts_jsr_errors[] = {
	{.name = "CTU MMIO Region", .error_code = 0x25},
	{.name = "MTS MMCRAB Region Access", .error_code = 0x24},
	{.name = "MTS_CARVEOUT Access from ARM SW", .error_code = 0x23},
	{.name = "NAFLL PLL Failure to Lock", .error_code = 0x22},
	{.name = "Internal Correctable MTS Error", .error_code = 0x21},
	{.name = "Internal Uncorrectable MTS Error", .error_code = 0x20},
	{}
};

/* Error Records per CORE - LSD_1 errors */
static struct ras_error lsd_1_errors[] = {
	{.name = "Core Cache Store Multi-line parity Error",
	 .error_code = 0x38},
	{.name = "Core-Cache Store ECC", .error_code = 0x37},
	{.name = "Core-Cache Store ECC", .error_code = 0x36},
	{.name = "Core-Cache Load ECC", .error_code = 0x35},
	{.name = "Core-Cache Load ECC", .error_code = 0x34},
	{.name = "Mini-Cache Data Load Parity", .error_code = 0x33},
	{.name = "Core Cache Multi-Hit", .error_code = 0x32},
	{.name = "Mini-Cache Multi-Hit", .error_code = 0x31},
	{.name = "Core-Cache Tag Parity", .error_code = 0x30},
	{}
};

/* Error Records per CORE - LSD_2 errors */
static struct ras_error lsd_2_errors[] = {
	{.name = "L2 Detected Error on LSD Request", .error_code = 0x49},
	{.name = "Coherent Cache Uncorrectable ECC", .error_code = 0x48},
	{.name = "Coherent Cache Correctable ECC", .error_code = 0x47},
	{.name = "Mini Cache Eviction Parity Error", .error_code = 0x46},
	{.name = "Version Cache Eviction Parity Error", .error_code = 0x45},
	{.name = "Version Cache Data ECC Uncorrectable", .error_code = 0x44},
	{.name = "Version Cache Data ECC Correctable", .error_code = 0x43},
	{.name = "BTU Core Cache Multi-Hit", .error_code = 0x42},
	{.name = "BTU Mini Cache PPN", .error_code = 0x41},
	{.name = "BTU Core Cache PPN", .error_code = 0x40},
	{}
};

/* Error Records per CORE - LSD_3 errors */
static struct ras_error lsd_3_errors[] = {
	{.name = "LSD Latent Fault 3", .error_code = 0x3D},
	{.name = "L2 TLB Parity Error", .error_code = 0x3C},
	{}
};

/* Error Records per CORE */
static struct error_record core_ers[] = {
	{.name = "IFU", .errx = 0,
	 .err_ctrl = RAS_CTL_ED | RAS_CTL_UE | RAS_CTL_CFI |
		ERR_CTL_IFU_ITLB_SNP_ERR | ERR_CTL_IFU_ICMH_ERR |
		ERR_CTL_IFU_ICTP_ERR | ERR_CTL_IFU_ICDP_ERR |
		ERR_CTL_IFU_THERR_ERR | ERR_CTL_IFU_ITLBP_ERR |
		ERR_CTL_IFU_ICMHSNP_ERR | ERR_CTL_IFU_ICTPSNP_ERR |
		ERR_CTL_IFU_L2UC_ERR | ERR_CTL_IFU_IMQDP_ERR |
		ERR_CTL_IFU_MITGRP_ERR,
	 .errors = ifu_errors},
	{.name = "RET_JSR", .errx = 1,
	 .err_ctrl = RAS_CTL_ED | RAS_CTL_UE |
		ERR_CTL_RET_JSR_TO_ERR | ERR_CTL_RET_JSR_GB_ERR |
		ERR_CTL_RET_JSR_IRFP_ERR | ERR_CTL_RET_JSR_FRFP_ERR,
	 .errors = ret_jsr_errors},
	{.name = "MTS_JSR", .errx = 2,
	 .err_ctrl = RAS_CTL_ED | RAS_CTL_UE | RAS_CTL_CFI |
		ERR_CTL_MTS_JSR_ERRUC_ERR | ERR_CTL_MTS_JSR_ERRC_ERR |
		ERR_CTL_MTS_JSR_NAFLL_ERR | ERR_CTL_MTS_JSR_CARVE_ERR |
		ERR_CTL_MTS_JSR_CRAB_ERR | ERR_CTL_MTS_JSR_MMIO_ERR,
	 .errors = mts_jsr_errors},
	{.name = "LSD_1", .errx = 3,
	 .err_ctrl = RAS_CTL_ED | RAS_CTL_UE | RAS_CTL_CFI |
		ERR_CTL_LSD1_CCTP_ERR | ERR_CTL_LSD1_MCMH_ERR |
		ERR_CTL_LSD1_CCMH_ERR | ERR_CTL_LSD1_MCDLP_ERR |
		ERR_CTL_LSD1_CCDLECC_S_ERR | ERR_CTL_LSD1_CCDLECC_D_ERR |
		ERR_CTL_LSD1_CCDSECC_S_ERR | ERR_CTL_LSD1_CCDSECC_D_ERR |
		ERR_CTL_LSD1_CCDEMLECC_ERR,
	 .errors = lsd_1_errors},
	{.name = "LSD_2", .errx = 4,
	 .err_ctrl = RAS_CTL_ED | RAS_CTL_UE | RAS_CTL_CFI |
		ERR_CTL_LSD2_BTCCVPP_ERR | ERR_CTL_LSD2_BTCCPPP_ERR |
		ERR_CTL_LSD2_BTCCMH_ERR | ERR_CTL_LSD2_VRCDECC_S_ERR |
		ERR_CTL_LSD2_VRCDECC_D_ERR | ERR_CTL_LSD2_VRCDP_ERR |
		ERR_CTL_LSD2_MCDEP_ERR | ERR_CTL_LSD2_CCDEECC_S_ERR |
		ERR_CTL_LSD2_CCDEECC_D_ERR | ERR_CTL_LSD2_L2REQ_UNCORR_ERR,
	 .errors = lsd_2_errors},
	{.name = "LSD_3", .errx = 5,
	 .err_ctrl = RAS_CTL_ED | RAS_CTL_UE | RAS_CTL_CFI |
		ERR_CTL_LSD3_L2TLBP_ERR | ERR_CTL_LSD3_LATENT_ERR,
	 .errors = lsd_3_errors},
	{}
};

/* Error Records per CORE CLUSTER - L2 errors
 * error_code = value of ARM_ERR_STATUS:IERR[15:8]
 */
static struct ras_error l2_errors[] = {
	{.name = "URT Timeout", .error_code = 0x68},
	{.name = "L2 Protocol Violation", .error_code = 0x67},
	{.name = "SCF to L2 Slave Error Read", .error_code = 0x66},
	{.name = "SCF to L2 Slave Error Write", .error_code = 0x65},
	{.name = "SCF to L2 Decode Error Read", .error_code = 0x64},
	{.name = "SCF to L2 Decode Error Write", .error_code = 0x63},
	{.name = "SCF to L2 Request Response Interface Parity Errors",
	 .error_code = 0x62},
	{.name = "SCF to L2 Advance notice interface parity errors",
	 .error_code = 0x61},
	{.name = "SCF to L2 Filldata Parity Errors", .error_code = 0x60},
	{.name = "SCF to L2 UnCorrectable ECC Data Error on interface",
	 .error_code = 0x5F},
	{.name = "SCF to L2 Correctable ECC Data Error on interface",
	 .error_code = 0x5E},
	{.name = "Core 1 to L2 Parity Error", .error_code = 0x5D},
	{.name = "Core 0 to L2 Parity Error", .error_code = 0x5C},
	{.name = "L2 Multi-Hit", .error_code = 0x5B},
	{.name = "L2 URT Tag Parity Error", .error_code = 0x5A},
	{.name = "L2 NTT Tag Parity Error", .error_code = 0x59},
	{.name = "L2 MLT Tag Parity Error", .error_code = 0x58},
	{.name = "L2 URD Data", .error_code = 0x57},
	{.name = "L2 NTP Data", .error_code = 0x56},
	{.name = "L2 MLC Uncorrectable Clean", .error_code = 0x54},
	{.name = "L2 URD Uncorrectable", .error_code = 0x53},
	{.name = "L2 MLC Uncorrectable Dirty", .error_code = 0x52},
	{.name = "L2 URD Correctable Error", .error_code = 0x51},
	{.name = "L2 MLC Correctable Error", .error_code = 0x50},
	{}
};

/* Error Records per CORE CLUSTER - MMU errors */
static struct ras_error mmu_errors[] = {
	{.name = "Walker Cache Parity Error", .error_code = 0x2D},
	{.name = "A$ Parity Error", .error_code = 0x2C},
	{}
};

/* Error Records per CORE CLUSTER - Cluster Clocks errors */
static struct ras_error cluster_clocks_errors[] = {
	{.name = "Walker Cache Parity Error", .error_code = 0x2D},
	{.name = "A$ Parity Error", .error_code = 0x2C},
	{}
};

/* Error Records per CORE CLUSTER */
static struct error_record corecluster_ers[] = {
	{.name = "L2", .errx = 0,
	 .err_ctrl = RAS_CTL_ED | RAS_CTL_UE | RAS_CTL_CFI |
		ERR_CTL_L2_MLD_ECCC_ERR | ERR_CTL_L2_URD_ECCC_ERR |
		ERR_CTL_L2_MLD_ECCUD_ERR | ERR_CTL_L2_URD_ECCU_ERR |
		ERR_CTL_L2_MLD_ECCUC_ERR | ERR_CTL_L2_NTDP_ERR |
		ERR_CTL_L2_URDP | ERR_CTL_L2_MLTP_ERR | ERR_CTL_L2_NTTP_ERR |
		ERR_CTL_L2_URTP_ERR | ERR_CTL_L2_L2MH_ERR |
		ERR_CTL_L2_CORE02L2CP_ERR | ERR_CTL_L2_CORE12L2CP_ERR |
		ERR_CTL_L2_SCF2L2C_ECCC_ERR | ERR_CTL_L2_SCF2L2C_ECCU_ERR |
		ERR_CTL_L2_SCF2L2C_FILLDATAP_ERR |
		ERR_CTL_L2_SCF2L2C_ADVNOTP_ERR |
		ERR_CTL_L2_SCF2L2C_REQRSPP_ERR |
		ERR_CTL_L2_SCF2L2C_DECWTERR_ERR |
		ERR_CTL_L2_SCF2L2C_DECRDERR_ERR |
		ERR_CTL_L2_SCF2L2C_SLVWTERR_ERR |
		ERR_CTL_L2_SCF2L2C_SLVRDERR_ERR | ERR_CTL_L2_L2PCL_ERR |
		ERR_CTL_L2_URTTO_ERR,
	.errors = l2_errors},
	{.name = "MMU", .errx = 2,
	 .err_ctrl = RAS_CTL_ED | RAS_CTL_CFI |
		ERR_CTL_MMU_ACPERR_ERR | ERR_CTL_MMU_WCPERR_ERR,
	 .errors = mmu_errors},
	{.name = "CLUSTER_CLOCKS", .errx = 1,
	 .err_ctrl = RAS_CTL_ED | RAS_CTL_UE | ERR_CTL_CC_FREQ_MON_ERR,
	 .errors = cluster_clocks_errors},
	{}
};

/* Error Records per CCPLEX - CMU:CCPMU errors
 * error_code = value of ARM_ERR_STATUS:IERR[15:8]
 */
static struct ras_error cmu_ccpmu_errors[] = {
	{.name = "DMCE Ucode Error", .error_code = 0x2A},
	{.name = "Crab Access Error", .error_code = 0x29},
	{.name = "DMCE Crab Access Error", .error_code = 0x28},
	{}
};

/* Error Records per CCPLEX - SCF:IOB errors */
static struct ras_error scf_iob_errors[] = {
	{.name = "CBB Interface Error", .error_code = 0x76},
	{.name = "IHI Interface Error", .error_code = 0x74},
	{.name = "MMCRAB Error", .error_code = 0x75},
	{.name = "CRI Error", .error_code = 0x73},
	{.name = "TBX Interface Error", .error_code = 0x72},
	{.name = "EVP Interface Error", .error_code = 0x71},
	{.name = "Uncorrectable ECC on Putdata", .error_code = 0x77},
	{.name = "Correctable ECC on Putdata", .error_code = 0x70},
	{.name = "Putdata parity Error", .error_code = 0x78},
	{.name = "Request Parity Error", .error_code = 0x79},
	{}
};

/* Error Records per CCPLEX - SCF:SNOC errors */
static struct ras_error scf_snoc_errors[] = {
	{.name = "Carveout Error", .error_code = 0x81},
	{.name = "Misc Client Parity Error", .error_code = 0x89},
	{.name = "Misc Filldata Parity Error", .error_code = 0x88},
	{.name = "Uncorrectable ECC Misc Client", .error_code = 0x87},
	{.name = "Correctable ECC Misc Client", .error_code = 0x80},
	{.name = "DVMU Interface Parity Error", .error_code = 0x86},
	{.name = "DVMU Interface Timeout Error", .error_code = 0x85},
	{.name = "CPE Request Error", .error_code = 0x84},
	{.name = "CPE Response Error", .error_code = 0x83},
	{.name = "CPE Timeout Error", .error_code = 0x82},
	{}
};

/* Error Records per CCPLEX - CMU:CTU errors */
static struct ras_error cmu_ctu_errors[] = {
	{.name = "Timeout Error for TRC_DMA request timeout",
	 .error_code = 0xB6},
	{.name = "Timeout Error for CTU Snp", .error_code = 0xB5},
	{.name = "Parity Error in CTU TAG RAM", .error_code = 0xB4},
	{.name = "Parity Error in CTU DATA RAM", .error_code = 0xB3},
	{.name = "Parity error for TRL requests from 9 agents",
	 .error_code = 0xB2},
	{.name = "Parity error for MCF request", .error_code = 0xB1},
	{.name = "TRC DMA fillsnoop parity error", .error_code = 0xB0},
	{}
};

/* Error Records per CCPLEX - SCF:L3_* errors */
static struct ras_error scf_l3_errors[] = {
	{.name = "L3 Timeout Error", .error_code = 0x91},
	{.name = "L3 Protocol Error", .error_code = 0x92},
	{.name = "Destination Error", .error_code = 0x90},
	{.name = "Unrecognised Command Error", .error_code = 0x93},
	{.name = "Multi-Hit Tage Error", .error_code = 0x94},
	{.name = "Multi-Hit CAM Error", .error_code = 0x95},
	{.name = "L3 Correctable ECC error", .error_code = 0x99},
	{.name = "L3 Tag Parity Error", .error_code = 0x98},
	{.name = "L3 Address Error", .error_code = 0x96},
	{}
};

/* Error Records per CCPLEX - SCFCMU_Clocks errors */
static struct ras_error scfcmu_clocks_errors[] = {
	{.name = "Voltage Error on ADC1 Monitored Logic", .error_code = 0xA3},
	{.name = "Voltage Error on ADC0 Monitored Logic", .error_code = 0xA2},
	{.name = "Lookup Table 1 Parity Error", .error_code = 0xA1},
	{.name = "Lookup Table 0 Parity Error", .error_code = 0xA0},
	{}
};

/* Error Records per CCPLEX */
static struct error_record ccplex_ers[] = {
	{.name = "CMU:CCPMU", .errx = 1024,
	 .err_ctrl = RAS_CTL_ED | RAS_CTL_UE |
		ERR_CTL_DPMU_DMCE_CRAB_ACC_ERR | ERR_CTL_DPMU_CRAB_ACC_ERR |
		ERR_CTL_DPMU_DMCE_UCODE_ERR,
	 .errors = cmu_ccpmu_errors},
	{.name = "SCF:IOB", .errx = 1025,
	 .err_ctrl = RAS_CTL_ED | RAS_CTL_UE | RAS_CTL_CFI |
		ERR_CTL_SCFIOB_REQ_PAR_ERR | ERR_CTL_SCFIOB_PUT_PAR_ERR |
		ERR_CTL_SCFIOB_PUT_CECC_ERR | ERR_CTL_SCFIOB_PUT_UECC_ERR |
		ERR_CTL_SCFIOB_EVP_ERR | ERR_CTL_SCFIOB_TBX_ERR |
		ERR_CTL_SCFIOB_CRI_ERR | ERR_CTL_SCFIOB_MMCRAB_ERR |
		ERR_CTL_SCFIOB_IHI_ERR | ERR_CTL_SCFIOB_CBB_ERR,
	 .errors = scf_iob_errors},
	{.name = "SCF:SNOC", .errx = 1026,
	 .err_ctrl = RAS_CTL_ED | RAS_CTL_UE | RAS_CTL_CFI |
		ERR_CTL_SCFSNOC_CPE_TO_ERR | ERR_CTL_SCFSNOC_CPE_RSP_ERR |
		ERR_CTL_SCFSNOC_CPE_REQ_ERR | ERR_CTL_SCFSNOC_DVMU_TO_ERR |
		ERR_CTL_SCFSNOC_DVMU_PAR_ERR | ERR_CTL_SCFSNOC_MISC_CECC_ERR |
		ERR_CTL_SCFSNOC_MISC_UECC_ERR | ERR_CTL_SCFSNOC_MISC_PAR_ERR |
		ERR_CTL_SCFSNOC_MISC_RSP_ERR | ERR_CTL_SCFSNOC_CARVEOUT_ERR,
	 .errors = scf_snoc_errors},
	{.name = "CMU:CTU", .errx = 1027,
	 .err_ctrl = RAS_CTL_ED | RAS_CTL_UE |
		ERR_CTL_CMUCTU_TRCDMA_PAR_ERR | ERR_CTL_CMUCTU_MCF_PAR_ERR |
		ERR_CTL_CMUCTU_TRL_PAR_ERR | ERR_CTL_CMUCTU_CTU_DATA_PAR_ERR |
		ERR_CTL_CMUCTU_TAG_PAR_ERR | ERR_CTL_CMUCTU_CTU_SNP_ERR |
		ERR_CTL_CMUCTU_TRCDMA_REQ_ERR,
	.errors = cmu_ctu_errors},
	{.name = "SCF:L3_0", .errx = 768,
	 .err_ctrl = RAS_CTL_ED | RAS_CTL_UE | RAS_CTL_CFI |
		ERR_CTL_SCFL3_ADR_ERR | ERR_CTL_SCFL3_PERR_ERR |
		ERR_CTL_SCFL3_UECC_ERR | ERR_CTL_SCFL3_CECC_ERR |
		ERR_CTL_SCFL3_MH_CAM_ERR | ERR_CTL_SCFL3_MH_TAG_ERR |
		ERR_CTL_SCFL3_UNSUPP_REQ_ERR | ERR_CTL_SCFL3_PROT_ERR |
		ERR_CTL_SCFL3_TO_ERR,
	 .errors = scf_l3_errors},
	{.name = "SCF:L3_1", .errx = 769,
	 .err_ctrl = RAS_CTL_ED | RAS_CTL_UE | RAS_CTL_CFI |
		ERR_CTL_SCFL3_ADR_ERR | ERR_CTL_SCFL3_PERR_ERR |
		ERR_CTL_SCFL3_UECC_ERR | ERR_CTL_SCFL3_CECC_ERR |
		ERR_CTL_SCFL3_MH_CAM_ERR | ERR_CTL_SCFL3_MH_TAG_ERR |
		ERR_CTL_SCFL3_UNSUPP_REQ_ERR | ERR_CTL_SCFL3_PROT_ERR |
		ERR_CTL_SCFL3_TO_ERR,
	 .errors = scf_l3_errors},
	{.name = "SCF:L3_2", .errx = 770,
	 .err_ctrl = RAS_CTL_ED | RAS_CTL_UE | RAS_CTL_CFI |
		ERR_CTL_SCFL3_ADR_ERR | ERR_CTL_SCFL3_PERR_ERR |
		ERR_CTL_SCFL3_UECC_ERR | ERR_CTL_SCFL3_CECC_ERR |
		ERR_CTL_SCFL3_MH_CAM_ERR | ERR_CTL_SCFL3_MH_TAG_ERR |
		ERR_CTL_SCFL3_UNSUPP_REQ_ERR | ERR_CTL_SCFL3_PROT_ERR |
		ERR_CTL_SCFL3_TO_ERR,
	 .errors = scf_l3_errors},
	{.name = "SCF:L3_3", .errx = 771,
	 .err_ctrl = RAS_CTL_ED | RAS_CTL_UE | RAS_CTL_CFI |
		ERR_CTL_SCFL3_ADR_ERR | ERR_CTL_SCFL3_PERR_ERR |
		ERR_CTL_SCFL3_UECC_ERR | ERR_CTL_SCFL3_CECC_ERR |
		ERR_CTL_SCFL3_MH_CAM_ERR | ERR_CTL_SCFL3_MH_TAG_ERR |
		ERR_CTL_SCFL3_UNSUPP_REQ_ERR | ERR_CTL_SCFL3_PROT_ERR |
		ERR_CTL_SCFL3_TO_ERR,
	 .errors = scf_l3_errors},
	{.name = "SCFCMU_CLOCKS", .errx = 1028,
	 .err_ctrl = RAS_CTL_ED | RAS_CTL_UE |
		ERR_CTL_SCFCMU_LUT0_PAR_ERR | ERR_CTL_SCFCMU_LUT1_PAR_ERR |
		ERR_CTL_SCFCMU_ADC0_MON_ERR | ERR_CTL_SCFCMU_ADC1_MON_ERR,
	 .errors = scfcmu_clocks_errors},
	{}
};

/* This is called for each online CPU during probe and is also used
 * as hotplug callback to enable RAS every time a core comes online
 */
static void carmel_ras_enable(void *info)
{
	u64 errx;
	int i;
	u8 cpu = smp_processor_id();

	/* Enable Core Error Records */
	for (i = 0; core_ers[i].name; i++) {
		errx = (tegra18_logical_to_cluster(cpu) << 5) +
			(tegra18_logical_to_cpu(cpu) << 4) +
			core_ers[i].errx;

		ras_write_errselr(errx);
		ras_write_error_control(core_ers[i].err_ctrl);
		ras_read_error_control();
	}

	/* Enable Core Cluster Error Records */
	for (i = 0; corecluster_ers[i].name; i++) {
		errx = 512 + (tegra18_logical_to_cluster(cpu) << 4) +
		       corecluster_ers[i].errx;

		ras_write_errselr(errx);
		ras_write_error_control(corecluster_ers[i].err_ctrl);
		ras_read_error_control();
	}

	/* Enable CCPLEX Error Records */
	for (i = 0; ccplex_ers[i].name; i++) {
		ras_write_errselr(ccplex_ers[i].errx);
		ras_write_error_control(ccplex_ers[i].err_ctrl);
		ras_read_error_control();
	}

	pr_info("%s:RAS enabled on cpu%d\n", __func__, cpu);
}

static int carmel_ras_enable_callback(unsigned int cpu)
{

	if (is_this_ras_cpu())
		smp_call_function_single(cpu, carmel_ras_enable, NULL, 1);

	return 0;
}

/* SERROR is triggered for Uncorrectable errors.
 * This is SERR Callback for error records per core.
 * A core will scan all other core's per core error records
 */
static int ras_core_serr_callback(struct pt_regs *regs, int reason,
			unsigned int esr, void *priv)
{
	u64 err_status;
	int cpu, errx;
	unsigned long flags;
	int retval = 1;
	struct error_record *record;

	if (!is_this_ras_cpu())
		return retval;

	pr_info("%s: Scanning Core Error Records for Uncorrectable Errors\n",
		__func__);
	raw_spin_lock_irqsave(&core_ras_lock, flags);
	/* scan all CPU's per core error records */
	for_each_online_cpu(cpu) {
		if (!tegra_is_cpu_carmel(cpu))
			continue;

		list_for_each_entry(record, &core_ras_list, node) {
			errx = (tegra18_logical_to_cluster(cpu) << 5) +
				(tegra18_logical_to_cpu(cpu) << 4) +
				record->errx;

			ras_write_errselr(errx);
			err_status = ras_read_error_status();
			if ((err_status & ERRi_STATUS_UE) &&
				(err_status & ERRi_STATUS_VALID)) {
				print_error_record(record, err_status);
				retval = 0;
			}
		}
	}
	raw_spin_unlock_irqrestore(&core_ras_lock, flags);
	return retval;
}

static struct serr_hook core_serr_callback = {
	.fn = ras_core_serr_callback
};

static void register_core_er(struct error_record *record)
{
	list_add(&record->node, &core_ras_list);
}

static void unregister_core_er(struct error_record *record)
{
	list_del(&record->node);
}

static void ras_register_core_ers(void)
{
	int i;

	for (i = 0; core_ers[i].name; i++)
		register_core_er(&core_ers[i]);
}

static void ras_unregister_core_ers(void)
{
	int i;

	for (i = 0; core_ers[i].name; i++)
		unregister_core_er(&core_ers[i]);
}

/*
 * This is used to handle FHI or Correctable Errors triggered from
 * error records per core.
 */
static void handle_fhi_core(void)
{
	u64 err_status;
	int cpu, errx;
	struct error_record *record;

	pr_info("%s: Scanning Core Error Records for Correctable Errors\n",
		__func__);
	/* scan all CPU's per core error records */
	for_each_online_cpu(cpu) {
		if (!tegra_is_cpu_carmel(cpu))
			continue;

		list_for_each_entry(record, &core_ras_list, node) {
			errx = (tegra18_logical_to_cluster(cpu) << 5) +
				(tegra18_logical_to_cpu(cpu) << 4) +
				record->errx;

			ras_write_errselr(errx);
			err_status = ras_read_error_status();
			if (get_error_status_ce(err_status) &&
				(err_status & ERRi_STATUS_VALID))
				print_error_record(record, err_status);
		}
	}
}

/* SERROR is triggered for Uncorrectable errors.
 * This is SERR Callback for error records per Core Cluster.
 */
static int ras_corecluster_serr_callback(struct pt_regs *regs, int reason,
			unsigned int esr, void *priv)
{
	u64 err_status;
	int cpu, errx;
	unsigned long flags;
	int retval = 1;
	struct error_record *record;

	if (!is_this_ras_cpu())
		return retval;

	pr_info("%s:Scanning CoreCluster Error Records for Uncorrectable "
		"Errors\n", __func__);
	raw_spin_lock_irqsave(&corecluster_ras_lock, flags);
	/* scan all CPU's per core error records */
	for_each_online_cpu(cpu) {
		if (!tegra_is_cpu_carmel(cpu))
			continue;

		list_for_each_entry(record, &corecluster_ras_list, node) {
			errx = 512 + (tegra18_logical_to_cluster(cpu) << 4) +
				record->errx;
			ras_write_errselr(errx);
			err_status = ras_read_error_status();

			if ((err_status & ERRi_STATUS_UE) &&
				(err_status & ERRi_STATUS_VALID)) {
				print_error_record(record, err_status);
				retval = 0;
			}
		}
	}
	raw_spin_unlock_irqrestore(&corecluster_ras_lock, flags);
	return retval;
}

static struct serr_hook corecluster_serr_callback = {
	.fn = ras_corecluster_serr_callback
};

static void register_corecluster_er(struct error_record *record)
{
	list_add(&record->node, &corecluster_ras_list);
}

static void unregister_corecluster_er(struct error_record *record)
{
	list_del(&record->node);
}

static void ras_register_corecluster_ers(void)
{
	int i;

	for (i = 0; corecluster_ers[i].name; i++)
		register_corecluster_er(&corecluster_ers[i]);
}

static void ras_unregister_corecluster_ers(void)
{
	int i;

	for (i = 0; corecluster_ers[i].name; i++)
		unregister_corecluster_er(&corecluster_ers[i]);
}

/* This is used to handle FHI or Correctable Errors
 * triggered from error records per Core Cluster
 */
static void handle_fhi_corecluster(void)
{
	u64 err_status;
	int cpu, errx;
	struct error_record *record;

	pr_info("%s:Scanning CoreCluster Error Records for Correctable Errors\n",
		__func__);
	for_each_online_cpu(cpu) {
		if (!tegra_is_cpu_carmel(cpu))
			continue;

		list_for_each_entry(record, &corecluster_ras_list, node) {
			errx = 512 + (tegra18_logical_to_cluster(cpu) << 4) +
				record->errx;
			ras_write_errselr(errx);
			err_status = ras_read_error_status();

			if (get_error_status_ce(err_status) &&
				(err_status & ERRi_STATUS_VALID))
				print_error_record(record, err_status);
		}
	}
}

/* SERROR is triggered for Uncorrectable errors.
 * This is SERR Callback for error records per CCPLEX.
 */
static int ras_ccplex_serr_callback(struct pt_regs *regs, int reason,
			unsigned int esr, void *priv)
{
	u64 err_status;
	unsigned long flags;
	int retval = 1;
	struct error_record *record;

	/* Return if this CPU doesn't support RAS */
	if (!is_this_ras_cpu())
		return retval;

	pr_info("%s: Scanning CCPLEX Error Records for Uncorrectable Errors\n",
		__func__);

	raw_spin_lock_irqsave(&ccplex_ras_lock, flags);
	list_for_each_entry(record, &ccplex_ras_list, node) {
		ras_write_errselr(record->errx);
		err_status = ras_read_error_status();
		if ((err_status & ERRi_STATUS_UE) &&
			(err_status & ERRi_STATUS_VALID)) {
			print_error_record(record, err_status);
			retval = 0;
		}
	}
	raw_spin_unlock_irqrestore(&ccplex_ras_lock, flags);
	return is_debug?1 : retval;
}

static struct serr_hook ccplex_serr_callback = {
	.fn = ras_ccplex_serr_callback
};

static void register_ccplex_er(struct error_record *record)
{
	list_add(&record->node, &ccplex_ras_list);
}

static void unregister_ccplex_er(struct error_record *record)
{
	list_del(&record->node);
}

static void ras_register_ccplex_ers(void)
{
	int i;

	for (i = 0; ccplex_ers[i].name; i++)
		register_ccplex_er(&ccplex_ers[i]);
}

static void ras_unregister_ccplex_ers(void)
{
	int i;

	for (i = 0; ccplex_ers[i].name; i++)
		unregister_ccplex_er(&ccplex_ers[i]);
}

/* This is used to handle FHI or Correctable Errors
 * triggered from error records per CCPLEX.
 */
static void handle_fhi_ccplex(void)
{
	u64 err_status;
	struct error_record *record;

	/* Return if  RAS is not supported on this CPU */
	if (!is_this_ras_cpu())
		return;

	pr_info("%s: Scanning CCPLEX Error Records for Correctable Errors\n",
		__func__);

	list_for_each_entry(record, &ccplex_ras_list, node) {
		ras_write_errselr(record->errx);
		err_status = ras_read_error_status();

		if (get_error_status_ce(err_status) &&
			(err_status & ERRi_STATUS_VALID))
			print_error_record(record, err_status);
	}
}

/* FHI is triggered for Correctable errors.
 * This is FHI Callback for handling error records per core,
 * per core cluster and per CCPLEX
 */
static void carmel_fhi_callback(void)
{
	handle_fhi_core();
	handle_fhi_corecluster();
	handle_fhi_ccplex();
}

static struct ras_fhi_callback fhi_callback = {
	.fn = carmel_fhi_callback
};

/* This function is used to trigger RAS Errors
 * depending upon the error record and error enabled
 * in the pfgctl passed to it
 */
static int ras_trip(u64 errx, u64 pfgctl)
{
	unsigned long flags, err_ctl;

	flags = arch_local_save_flags();

	/* Print some debug information */
	pr_crit("%s: DAIF = 0x%lx\n", __func__, flags);
	if (flags & 0x4) {
		pr_crit("%s: \"A\" not set", __func__);
		return 0;
	}

	ras_write_errselr(errx);
	pr_info("%s: Error Record Selected = %lld\n",
		__func__, ras_read_errselr());

	err_ctl = ras_read_error_control();
	pr_crit("%s:Error Record ERRCTL = 0x%lx\n", __func__, err_ctl);
	if (!(err_ctl & RAS_CTL_ED)) {
		pr_crit("%s: Error Detection is not enabled", __func__);
		return 0;
	}

	/* Write some value to MISC0 */
	ras_write_error_misc0(ERRi_MISC0_CONST);
	/* Write some value to MISC1 */
	ras_write_error_misc1(ERRi_MISC1_CONST);
	/* Write some value to ADDR */
	ras_write_error_addr(ERRi_ADDR_CONST);
	is_debug = 1;
	/* Set coundown value */
	ras_write_pfg_cdn(ERRi_PFGCDN_CDN_1);
	/* Write to ERR<X>PFGCTL */
	pr_info("%s:Writing 0x%llx to ERRXPFGCTL\n", __func__, pfgctl);
	ras_write_pfg_control(pfgctl);
	return 0;
}

static int l3_cecc_put(void *data, u64 val)
{
	return ras_trip(ERRX_SCFL3, val);
}

/* This will return the special value to be written to debugfs node
 * L3_0_CECC_ERR-trip to trigger L3_0_CECC Error
 * Value is written to PFGCTL register.
 * Enables bits CECC_ERR|CDNEN|MV|AV|CE|UC
 */
static int l3_cecc_get(void *data, u64 *val)
{
	*val = ERRi_PFGCTL_UC | ERRi_PFGCTL_CE | ERRi_PFGCTL_CDNEN |
		ERR_CTL_SCFL3_CECC_ERR;
	return 0;
}

static int scf_iob_cecc_put(void *data, u64 val)
{
	return ras_trip(ERRX_SCFIOB, val);
}

/* This will return the special value to be written to debugfs node
 * SCF_IOB-PUTDATA_CECC_ERR-trip to trigger SCF IOB PUTDATA_CECC Error
 */
static int scf_iob_cecc_get(void *data, u64 *val)
{
	*val = ERRi_PFGCTL_UC | ERRi_PFGCTL_CE | ERRi_PFGCTL_CDNEN |
		ERR_CTL_SCFIOB_PUT_CECC_ERR;
	return 0;
}

static int scf_iob_cbb_put(void *data, u64 val)
{
	return ras_trip(ERRX_SCFIOB, val);
}

/* This will return the special value to be written to debugfs node
 * SCF_IOB-CBB_ERR-trip to trigger SCF IOB CBB Error
 */
static int scf_iob_cbb_get(void *data, u64 *val)
{
	*val = ERRi_PFGCTL_UC | ERRi_PFGCTL_CE | ERRi_PFGCTL_CDNEN |
		ERR_CTL_SCFIOB_CBB_ERR;
	return 0;
}

static int scf_iob_cbb_open(struct inode *inode, struct file *file)
{
	return simple_attr_open(inode, file, scf_iob_cbb_get, scf_iob_cbb_put,
				"0x%08lx");
}

static int scf_iob_cecc_open(struct inode *inode, struct file *file)
{
	return simple_attr_open(inode, file, scf_iob_cecc_get, scf_iob_cecc_put,
				"0x%08lx");
}

static int l3_cecc_open(struct inode *inode, struct file *file)
{
	return simple_attr_open(inode, file, l3_cecc_get, l3_cecc_put,
				"0x%08lx");
}

static const struct file_operations fops_scf_iob_cbb = {
	.read =		simple_attr_read,
	.write =	simple_attr_write,
	.open =		scf_iob_cbb_open,
	.llseek =	noop_llseek,
};

static const struct file_operations fops_scf_iob_cecc = {
	.read =		simple_attr_read,
	.write =	simple_attr_write,
	.open =		scf_iob_cecc_open,
	.llseek =	noop_llseek,
};

static const struct file_operations fops_l3_cecc = {
	.read =		simple_attr_read,
	.write =	simple_attr_write,
	.open =		l3_cecc_open,
	.llseek =	noop_llseek,
};

static int ras_carmel_dbgfs_init(void)
{

	/* Install debugfs nodes to test RAS */
	debugfs_dir = debugfs_create_dir("carmel_ras", NULL);
	if (!debugfs_dir) {
		pr_err("Error creating carmel_ras debugfs dir.\n");
		return -ENODEV;
	}

	debugfs_node = debugfs_create_file("SCF_IOB-CBB_ERR-trip", 0600,
			 debugfs_dir, NULL, &fops_scf_iob_cbb);
	if (!debugfs_node) {
		pr_err("Error creating SCF_IOB-CBB_ERR-trip debugfs node.\n");
		return -ENODEV;
	}

	debugfs_node = debugfs_create_file("SCF_IOB-PUTDATA_CECC_ERR-trip",
			 0600, debugfs_dir, NULL, &fops_scf_iob_cecc);
	if (!debugfs_node) {
		pr_err("Error creating SCF_IOB-PUTDATA_CECC_ERR-trip debugfs node.\n");
		return -ENODEV;
	}

	debugfs_node = debugfs_create_file("L3_0_CECC_ERR-trip", 0600,
					debugfs_dir, NULL, &fops_l3_cecc);
	if (!debugfs_node) {
		pr_err("Error creating L3_0_CECC_ERR-trip debugfs node.\n");
		return -ENODEV;
	}
	return 0;
}

static int ras_carmel_probe(struct platform_device *pdev)
{
	int cpu, do_init = 0, ret = -1;
	struct device *dev = &pdev->dev;

	if (!is_ras_ready()) {
		dev_info(dev, "Deferring probe, arm64_ras hasnt been probed yet");
		return -EPROBE_DEFER;
	}

	/* probe only if RAS is supported on any of the online CPUs */
	for_each_online_cpu(cpu) {
		if (tegra_is_cpu_carmel(cpu) && is_ras_cpu(cpu))
			do_init = 1;
	}

	if (!do_init) {
		dev_info(dev, "None of the CPUs support RAS");
		return 0;
	}

	ras_register_core_ers();
	ras_register_corecluster_ers();
	ras_register_ccplex_ers();

	/* register FHI callback for Correctable Errors */
	ret = register_fhi_callback(&fhi_callback, pdev);
	if (ret) {
		dev_err(dev, "Failed to register FHI callback\n");
		return -ENOENT;
	}

	/* Ensure that any CPU brought online sets up RAS */
	ret = cpuhp_setup_state(CPUHP_AP_ONLINE_DYN,
				  "ras_carmel:online",
				  carmel_ras_enable_callback,
				  NULL);
	if (ret < 0) {
		dev_err(dev, "unable to register cpu hotplug state\n");
		return ret;
	}

	hp_state = ret;

	/* register SERR for Uncorrectable Errors */
	register_serr_hook(&core_serr_callback);
	register_serr_hook(&corecluster_serr_callback);
	register_serr_hook(&ccplex_serr_callback);

	/* Enable RAS on all online CPUs */
	for_each_online_cpu(cpu) {
		smp_call_function_single(cpu, carmel_ras_enable, NULL, 1);
	}

	ret = ras_carmel_dbgfs_init();
	if (ret)
		return ret;

	dev_info(dev, "probed");
	return 0;
}

static int ras_carmel_remove(struct platform_device *pdev)
{
	unregister_fhi_callback(&fhi_callback);

	unregister_serr_hook(&core_serr_callback);
	unregister_serr_hook(&corecluster_serr_callback);
	unregister_serr_hook(&ccplex_serr_callback);

	cpuhp_remove_state(hp_state);

	ras_unregister_core_ers();
	ras_unregister_corecluster_ers();
	ras_unregister_ccplex_ers();

	return 0;
}

static const struct of_device_id ras_carmel_of_match[] = {
	{
		.name = "carmel_ras",
		.compatible = "nvidia,carmel-ras",
	},
	{ },
};
MODULE_DEVICE_TABLE(of, ras_carmel_of_match);

static struct platform_driver ras_carmel_driver = {
	.probe = ras_carmel_probe,
	.remove = ras_carmel_remove,
	.driver = {
		.owner = THIS_MODULE,
		.name = "carmel_ras",
		.of_match_table = of_match_ptr(ras_carmel_of_match),
	},
};

static int __init ras_carmel_init(void)
{
	return platform_driver_register(&ras_carmel_driver);
}

static void __exit ras_carmel_exit(void)
{
	platform_driver_unregister(&ras_carmel_driver);
}

arch_initcall(ras_carmel_init);
module_exit(ras_carmel_exit);

MODULE_LICENSE("GPL v2");
MODULE_DESCRIPTION("Carmel RAS handler");
