/*
 * drivers/misc/tegra-profiler/main.c
 *
 * Copyright (c) 2013-2018, NVIDIA CORPORATION.  All rights reserved.
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
 */

#define pr_fmt(fmt) KBUILD_MODNAME ": " fmt

#include <linux/init.h>
#include <linux/module.h>
#include <linux/err.h>
#include <linux/sched.h>

#include <linux/tegra_profiler.h>

#include "quadd.h"
#include "arm_pmu.h"
#include "hrt.h"
#include "comm.h"
#include "mmap.h"
#include "debug.h"
#include "tegra.h"
#include "power_clk.h"
#include "auth.h"
#include "version.h"
#include "quadd_proc.h"
#include "eh_unwind.h"

#ifdef CONFIG_ARM64
#include "armv8_pmu.h"
#else
#include "armv7_pmu.h"
#endif

#ifdef CONFIG_CACHE_L2X0
#include "pl310.h"
#endif

static struct quadd_ctx ctx;
static DEFINE_PER_CPU(struct source_info, ctx_pmu_info);
static DEFINE_PER_CPU(struct quadd_comm_cap_for_cpu, per_cpu_caps);

static struct source_info *get_pmu_info_for_current_cpu(void)
{
	return this_cpu_ptr(&ctx_pmu_info);
}

static struct quadd_comm_cap_for_cpu *get_capabilities_for_cpu_int(int cpuid)
{
	return &per_cpu(per_cpu_caps, cpuid);
}

int tegra_profiler_try_lock(void)
{
	return atomic_cmpxchg(&ctx.tegra_profiler_lock, 0, 1);
}
EXPORT_SYMBOL_GPL(tegra_profiler_try_lock);

void tegra_profiler_unlock(void)
{
	atomic_set(&ctx.tegra_profiler_lock, 0);
}
EXPORT_SYMBOL_GPL(tegra_profiler_unlock);

static int start(void)
{
	int err;

	if (tegra_profiler_try_lock()) {
		pr_err("Error: tegra_profiler lock\n");
		return -EBUSY;
	}

	if (!atomic_cmpxchg(&ctx.started, 0, 1)) {
		if (quadd_mode_is_sampling(&ctx)) {
			if (ctx.pmu) {
				err = ctx.pmu->enable();
				if (err) {
					pr_err("error: pmu enable\n");
					goto errout;
				}
			}

			if (ctx.pl310) {
				err = ctx.pl310->enable();
				if (err) {
					pr_err("error: pl310 enable\n");
					goto errout;
				}
			}
		}

		ctx.comm->reset();

		err = quadd_hrt_start();
		if (err) {
			pr_err("error: hrt start\n");
			goto errout;
		}

		err = quadd_power_clk_start();
		if (err < 0) {
			pr_err("error: power_clk start\n");
			goto errout;
		}
	}

	return 0;

errout:
	atomic_set(&ctx.started, 0);
	tegra_profiler_unlock();

	return err;
}

static void stop(void)
{
	if (atomic_cmpxchg(&ctx.started, 1, 0)) {
		quadd_hrt_stop();
		quadd_power_clk_stop();
		ctx.comm->reset();
		quadd_unwind_stop();

		if (ctx.pmu)
			ctx.pmu->disable();

		if (ctx.pl310)
			ctx.pl310->disable();

		tegra_profiler_unlock();
	}
}

static inline int
is_event_supported(struct source_info *si, const struct quadd_event *event)
{
	unsigned int type, id;
	int i, nr = si->nr_supp_events;
	struct quadd_event *events = si->supp_events;

	type = event->type;
	id = event->id;

	if (type == QUADD_EVENT_TYPE_RAW)
		return (id & ~si->raw_event_mask) == 0;

	if (type == QUADD_EVENT_TYPE_HARDWARE) {
		for (i = 0; i < nr; i++) {
			if (id == events[i].id)
				return 1;
		}
	}

	return 0;
}

static int
validate_freq(unsigned int freq)
{
	return freq >= 100 && freq <= 100000;
}

static int
set_parameters_for_cpu(struct quadd_pmu_setup_for_cpu *params)
{
	int i, err, nr_pmu = 0;
	int cpuid = params->cpuid;

	struct source_info *pmu_info = &per_cpu(ctx_pmu_info, cpuid);
	struct quadd_event pmu_events[QUADD_MAX_COUNTERS];

	if (!ctx.mode_is_sampling)
		return -EINVAL;

	if (!pmu_info->is_present)
		return -ENODEV;

	if (pmu_info->nr_supp_events == 0)
		return -ENODEV;

	if (params->nr_events > QUADD_MAX_COUNTERS)
		return -EINVAL;

	for (i = 0; i < params->nr_events; i++) {
		struct quadd_event *event = &params->events[i];

		if (is_event_supported(pmu_info, event)) {
			pmu_events[nr_pmu++] = *event;
			pr_debug("[%d] PMU active event: %#x (%s)\n",
				 cpuid, event->id,
				 event->type == QUADD_EVENT_TYPE_RAW ?
				 "raw" : "hw");
		} else {
			pr_err("[%d] Bad event: %#x (%s)\n", cpuid, event->id,
			       event->type == QUADD_EVENT_TYPE_RAW ?
			       "raw" : "hw");
			return -EINVAL;
		}
	}

	err = ctx.pmu->set_events(cpuid, pmu_events, nr_pmu);
	if (err) {
		pr_err("PMU set parameters: error\n");
		return err;
	}
	per_cpu(ctx_pmu_info, cpuid).active = 1;

	return err;
}

static int verify_app(struct quadd_parameters *p, uid_t task_uid)
{
	int err;
	uid_t uid = 0;

	err = quadd_auth_is_debuggable((char *)p->package_name, &uid);
	if (err < 0) {
		pr_err("error: app either non-debuggable or not found: %s\n",
		       p->package_name);
		return err;
	}

	pr_info("app \"%s\" is debuggable, uid: %u\n",
		p->package_name, (unsigned int)uid);

	if (task_uid != uid) {
		pr_err("error: uids are not matched: %u, %u\n",
		       (unsigned int)task_uid, (unsigned int)uid);
		return -EACCES;
	}

	return 0;
}

static int
set_parameters(struct quadd_parameters *p)
{
	int i, err = 0, nr_pl310 = 0;
	uid_t task_uid, current_uid;
	struct quadd_event *pl310_events;
	struct task_struct *task = NULL;
	u64 *low_addr_p;
	u32 extra;

	extra = p->reserved[QUADD_PARAM_IDX_EXTRA];

	ctx.mode_is_sampling =
		extra & QUADD_PARAM_EXTRA_SAMPLING ? 1 : 0;
	ctx.mode_is_tracing =
		extra & QUADD_PARAM_EXTRA_TRACING ? 1 : 0;
	ctx.mode_is_sample_all =
		extra & QUADD_PARAM_EXTRA_SAMPLE_ALL_TASKS ? 1 : 0;
	ctx.mode_is_trace_all = p->trace_all_tasks;
	ctx.mode_is_sample_tree =
		extra & QUADD_PARAM_EXTRA_SAMPLE_TREE ? 1 : 0;
	ctx.mode_is_trace_tree =
		extra & QUADD_PARAM_EXTRA_TRACE_TREE ? 1 : 0;

	pr_info("flags: s/t/sa/ta/st/tt: %u/%u/%u/%u/%u/%u\n",
		ctx.mode_is_sampling,
		ctx.mode_is_tracing,
		ctx.mode_is_sample_all,
		ctx.mode_is_trace_all,
		ctx.mode_is_sample_tree,
		ctx.mode_is_trace_tree);

	if ((ctx.mode_is_trace_all || ctx.mode_is_sample_all) &&
	    !capable(CAP_SYS_ADMIN)) {
		pr_err("error: \"all tasks\" modes are allowed only for root\n");
		return -EACCES;
	}

	p->package_name[sizeof(p->package_name) - 1] = '\0';
	ctx.param = *p;

	current_uid = from_kuid(&init_user_ns, current_fsuid());
	pr_info("owner uid: %u\n", current_uid);

	if ((ctx.mode_is_tracing && !ctx.mode_is_trace_all) ||
	    (ctx.mode_is_sampling && !ctx.mode_is_sample_all)) {
		if (ctx.mode_is_sampling && !validate_freq(p->freq)) {
			pr_err("error: incorrect frequency: %u\n", p->freq);
			return -EINVAL;
		}

		/* Currently only first process */
		if (p->nr_pids != 1)
			return -EINVAL;

		task = get_pid_task(find_vpid(p->pids[0]), PIDTYPE_PID);
		if (!task) {
			pr_err("error: process not found: %u\n", p->pids[0]);
			return -ESRCH;
		}

		task_uid = from_kuid(&init_user_ns, task_uid(task));
		pr_info("task uid: %u\n", task_uid);

		if (!capable(CAP_SYS_ADMIN)) {
			if (current_uid != task_uid) {
				err = verify_app(p, task_uid);
				if (err < 0)
					goto out_put_task;
			}
			ctx.collect_kernel_ips = 0;
		} else {
			ctx.collect_kernel_ips = 1;
		}

		for (i = 0; i < p->nr_events; i++) {
			unsigned int type, id;
			struct quadd_event *event = &p->events[i];

			type = event->type;
			id = event->id;

			if (type != QUADD_EVENT_TYPE_HARDWARE) {
				err = -EINVAL;
				goto out_put_task;
			}

			if (ctx.pl310 &&
			    ctx.pl310_info.nr_supp_events > 0 &&
			    is_event_supported(&ctx.pl310_info, event)) {
				pl310_events = event;

				pr_debug("PL310 active event: %s\n",
					 quadd_get_hw_event_str(id));

				if (nr_pl310++ > 1) {
					pr_err("error: multiply pl310 events\n");
					err = -EINVAL;
					goto out_put_task;
				}
			} else {
				pr_err("Bad event: %s\n",
				       quadd_get_hw_event_str(id));
				err = -EINVAL;
				goto out_put_task;
			}
		}

		if (ctx.pl310) {
			int cpuid = 0; /* We don't need cpuid for pl310.  */

			if (nr_pl310 == 1) {
				err = ctx.pl310->set_events(cpuid,
							    pl310_events, 1);
				if (err) {
					pr_info("pl310 set_parameters: error\n");
					goto out_put_task;
				}
				ctx.pl310_info.active = 1;
			} else {
				ctx.pl310_info.active = 0;
				ctx.pl310->set_events(cpuid, NULL, 0);
			}
		}

		low_addr_p =
			(u64 *)&p->reserved[QUADD_PARAM_IDX_BT_LOWER_BOUND];
		ctx.hrt->low_addr = (unsigned long)*low_addr_p;
		pr_info("bt lower bound: %#lx\n", ctx.hrt->low_addr);

		err = quadd_unwind_start(task);
		if (err)
			goto out_put_task;
	}

	pr_info("New parameters have been applied\n");

out_put_task:
	if (task)
		put_task_struct(task);

	return err;
}

static void
get_capabilities_for_cpu(int cpuid, struct quadd_comm_cap_for_cpu *cap)
{
	int i, id;
	struct quadd_events_cap *events_cap;
	struct source_info *s = &per_cpu(ctx_pmu_info, cpuid);

	if (!s->is_present)
		return;

	cap->cpuid = cpuid;
	cap->l2_cache = 0;
	cap->l2_multiple_events = 0;

	events_cap = &cap->events_cap;

	events_cap->raw_event_mask = s->raw_event_mask;

	events_cap->cpu_cycles = 0;
	events_cap->l1_dcache_read_misses = 0;
	events_cap->l1_dcache_write_misses = 0;
	events_cap->l1_icache_misses = 0;

	events_cap->instructions = 0;
	events_cap->branch_instructions = 0;
	events_cap->branch_misses = 0;
	events_cap->bus_cycles = 0;

	events_cap->l2_dcache_read_misses = 0;
	events_cap->l2_dcache_write_misses = 0;
	events_cap->l2_icache_misses = 0;

	for (i = 0; i < s->nr_supp_events; i++) {
		struct quadd_event *event = &s->supp_events[i];

		id = event->id;

		if (id == QUADD_EVENT_HW_L2_DCACHE_READ_MISSES ||
		    id == QUADD_EVENT_HW_L2_DCACHE_WRITE_MISSES ||
		    id == QUADD_EVENT_HW_L2_ICACHE_MISSES) {
			cap->l2_cache = 1;
			cap->l2_multiple_events = 1;
		}

		switch (id) {
		case QUADD_EVENT_HW_CPU_CYCLES:
			events_cap->cpu_cycles = 1;
			break;
		case QUADD_EVENT_HW_INSTRUCTIONS:
			events_cap->instructions = 1;
			break;
		case QUADD_EVENT_HW_BRANCH_INSTRUCTIONS:
			events_cap->branch_instructions = 1;
			break;
		case QUADD_EVENT_HW_BRANCH_MISSES:
			events_cap->branch_misses = 1;
			break;
		case QUADD_EVENT_HW_BUS_CYCLES:
			events_cap->bus_cycles = 1;
			break;

		case QUADD_EVENT_HW_L1_DCACHE_READ_MISSES:
			events_cap->l1_dcache_read_misses = 1;
			break;
		case QUADD_EVENT_HW_L1_DCACHE_WRITE_MISSES:
			events_cap->l1_dcache_write_misses = 1;
			break;
		case QUADD_EVENT_HW_L1_ICACHE_MISSES:
			events_cap->l1_icache_misses = 1;
			break;

		case QUADD_EVENT_HW_L2_DCACHE_READ_MISSES:
			events_cap->l2_dcache_read_misses = 1;
			break;
		case QUADD_EVENT_HW_L2_DCACHE_WRITE_MISSES:
			events_cap->l2_dcache_write_misses = 1;
			break;
		case QUADD_EVENT_HW_L2_ICACHE_MISSES:
			events_cap->l2_icache_misses = 1;
			break;

		default:
			pr_err_once("%s: error: invalid event\n",
						__func__);
			return;
		}
	}
}

static u32 get_possible_cpu(void)
{
	int cpu;
	u32 mask = 0;
	struct source_info *s;

	if (ctx.pmu) {
		for_each_possible_cpu(cpu) {
			/* since we don't support more than 32 CPUs */
			if (cpu >= BITS_PER_BYTE * sizeof(mask))
				break;

			s = &per_cpu(ctx_pmu_info, cpu);
			if (s->is_present)
				mask |= (1U << cpu);
		}
	}

	return mask;
}

static void
get_capabilities(struct quadd_comm_cap *cap)
{
	int i;
	unsigned int extra = 0;
	struct quadd_events_cap *events_cap = &cap->events_cap;

	cap->pmu = ctx.pmu ? 1 : 0;

	cap->l2_cache = 0;
	if (ctx.pl310) {
		cap->l2_cache = 1;
		cap->l2_multiple_events = 0;
	}

	events_cap->cpu_cycles = 0;
	events_cap->l1_dcache_read_misses = 0;
	events_cap->l1_dcache_write_misses = 0;
	events_cap->l1_icache_misses = 0;

	events_cap->instructions = 0;
	events_cap->branch_instructions = 0;
	events_cap->branch_misses = 0;
	events_cap->bus_cycles = 0;

	events_cap->l2_dcache_read_misses = 0;
	events_cap->l2_dcache_write_misses = 0;
	events_cap->l2_icache_misses = 0;

	if (ctx.pl310) {
		unsigned int type, id;
		struct source_info *s = &ctx.pl310_info;

		for (i = 0; i < s->nr_supp_events; i++) {
			struct quadd_event *event = &s->supp_events[i];

			type = event->type;
			id = event->id;

			switch (id) {
			case QUADD_EVENT_HW_L2_DCACHE_READ_MISSES:
				events_cap->l2_dcache_read_misses = 1;
				break;
			case QUADD_EVENT_HW_L2_DCACHE_WRITE_MISSES:
				events_cap->l2_dcache_write_misses = 1;
				break;
			case QUADD_EVENT_HW_L2_ICACHE_MISSES:
				events_cap->l2_icache_misses = 1;
				break;

			default:
				pr_err_once("%s: error: invalid event\n",
					    __func__);
				return;
			}
		}
	}

	cap->tegra_lp_cluster = quadd_is_cpu_with_lp_cluster();
	cap->power_rate = 1;
	cap->blocked_read = 1;

	extra |= QUADD_COMM_CAP_EXTRA_BT_KERNEL_CTX;
	extra |= QUADD_COMM_CAP_EXTRA_GET_MMAP;
	extra |= QUADD_COMM_CAP_EXTRA_GROUP_SAMPLES;
	extra |= QUADD_COMM_CAP_EXTRA_BT_UNWIND_TABLES;
	extra |= QUADD_COMM_CAP_EXTRA_SUPPORT_AARCH64;
	extra |= QUADD_COMM_CAP_EXTRA_SPECIAL_ARCH_MMAP;
	extra |= QUADD_COMM_CAP_EXTRA_UNWIND_MIXED;
	extra |= QUADD_COMM_CAP_EXTRA_UNW_ENTRY_TYPE;
	extra |= QUADD_COMM_CAP_EXTRA_RB_MMAP_OP;
	extra |= QUADD_COMM_CAP_EXTRA_CPU_MASK;

	if (ctx.hrt->tc) {
		extra |= QUADD_COMM_CAP_EXTRA_ARCH_TIMER;
		if (ctx.hrt->arch_timer_user_access)
			extra |= QUADD_COMM_CAP_EXTRA_ARCH_TIMER_USR;
	}

	cap->reserved[QUADD_COMM_CAP_IDX_EXTRA] = extra;
	cap->reserved[QUADD_COMM_CAP_IDX_CPU_MASK] = get_possible_cpu();
}

void quadd_get_state(struct quadd_module_state *state)
{
	unsigned int status = 0;

	quadd_hrt_get_state(state);

	if (ctx.comm->is_active())
		status |= QUADD_MOD_STATE_STATUS_IS_ACTIVE;

	if (quadd_auth_is_auth_open())
		status |= QUADD_MOD_STATE_STATUS_IS_AUTH_OPEN;

	state->reserved[QUADD_MOD_STATE_IDX_STATUS] = status;
}

static int
set_extab(struct quadd_sections *extabs,
	  struct quadd_mmap_area *mmap)
{
	return quadd_unwind_set_extab(extabs, mmap);
}

static void
delete_mmap(struct quadd_mmap_area *mmap)
{
	quadd_unwind_delete_mmap(mmap);
}

static int
is_cpu_present(int cpuid)
{
	struct source_info *s = &per_cpu(ctx_pmu_info, cpuid);

	return s->is_present;
}

static struct quadd_comm_control_interface control = {
	.start			= start,
	.stop			= stop,
	.set_parameters		= set_parameters,
	.set_parameters_for_cpu = set_parameters_for_cpu,
	.get_capabilities	= get_capabilities,
	.get_capabilities_for_cpu = get_capabilities_for_cpu,
	.get_state		= quadd_get_state,
	.set_extab		= set_extab,
	.delete_mmap		= delete_mmap,
	.is_cpu_present		= is_cpu_present,
};

static int __init quadd_module_init(void)
{
	int i, nr_events, err;
	unsigned int raw_event_mask;
	struct quadd_event *events;
	int cpuid;

	pr_info("Branch: %s\n", QUADD_MODULE_BRANCH);
	pr_info("Version: %s\n", QUADD_MODULE_VERSION);
	pr_info("Samples version: %d\n", QUADD_SAMPLES_VERSION);
	pr_info("IO version: %d\n", QUADD_IO_VERSION);

#ifdef QM_DEBUG_SAMPLES_ENABLE
	pr_info("############## DEBUG VERSION! ##############\n");
#endif

	atomic_set(&ctx.started, 0);
	atomic_set(&ctx.tegra_profiler_lock, 0);

	ctx.get_capabilities_for_cpu = get_capabilities_for_cpu_int;
	ctx.get_pmu_info = get_pmu_info_for_current_cpu;

	for_each_possible_cpu(cpuid) {
		struct source_info *pmu_info = &per_cpu(ctx_pmu_info, cpuid);

		pmu_info->active = 0;
		pmu_info->is_present = 0;
	}

	ctx.pl310_info.active = 0;

#ifdef CONFIG_ARM64
	ctx.pmu = quadd_armv8_pmu_init();
#else
	ctx.pmu = quadd_armv7_pmu_init();
#endif
	if (!ctx.pmu) {
		pr_err("PMU init failed\n");
		return -ENODEV;
	}

	for_each_possible_cpu(cpuid) {
		struct quadd_arch_info *arch;
		struct source_info *pmu_info;

		arch = ctx.pmu->get_arch(cpuid);
		if (!arch)
			continue;

		pmu_info = &per_cpu(ctx_pmu_info, cpuid);
		pmu_info->is_present = 1;

		events = pmu_info->supp_events;
		nr_events =
		    ctx.pmu->get_supported_events(cpuid, events,
						  QUADD_MAX_COUNTERS,
						  &raw_event_mask);

		pmu_info->nr_supp_events = nr_events;
		pmu_info->raw_event_mask = raw_event_mask;

		pr_debug("CPU: %d PMU: amount of events: %d, raw mask: %#x\n",
			 cpuid, nr_events, raw_event_mask);

		for (i = 0; i < nr_events; i++)
			pr_debug("CPU: %d PMU event: %s\n", cpuid,
				 quadd_get_hw_event_str(events[i].id));
	}

#ifdef CONFIG_CACHE_L2X0
	ctx.pl310 = quadd_l2x0_events_init();
#else
	ctx.pl310 = NULL;
#endif
	if (ctx.pl310) {
		events = ctx.pl310_info.supp_events;
		nr_events = ctx.pl310->get_supported_events(0, events,
							    QUADD_MAX_COUNTERS,
							    &raw_event_mask);
		ctx.pl310_info.nr_supp_events = nr_events;

		pr_info("pl310 success, amount of events: %d\n",
			nr_events);

		for (i = 0; i < nr_events; i++)
			pr_info("pl310 event: %s\n",
				quadd_get_hw_event_str(events[i].id));
	} else {
		pr_debug("PL310 not found\n");
	}

	ctx.hrt = quadd_hrt_init(&ctx);
	if (IS_ERR(ctx.hrt)) {
		pr_err("error: HRT init failed\n");
		return PTR_ERR(ctx.hrt);
	}

	err = quadd_power_clk_init(&ctx);
	if (err < 0) {
		pr_err("error: POWER CLK init failed\n");
		return err;
	}

	ctx.comm = quadd_comm_events_init(&ctx, &control);
	if (IS_ERR(ctx.comm)) {
		pr_err("error: COMM init failed\n");
		return PTR_ERR(ctx.comm);
	}

	err = quadd_auth_init(&ctx);
	if (err < 0) {
		pr_err("error: auth failed\n");
		return err;
	}

	err = quadd_unwind_init();
	if (err < 0) {
		pr_err("error: EH unwinding init failed\n");
		return err;
	}

	get_capabilities(&ctx.cap);

	for_each_possible_cpu(cpuid)
		get_capabilities_for_cpu(cpuid, &per_cpu(per_cpu_caps, cpuid));

	quadd_proc_init(&ctx);

	return 0;
}

static void __exit quadd_module_exit(void)
{
	pr_info("QuadD module exit\n");

	quadd_hrt_deinit();
	quadd_power_clk_deinit();
	quadd_comm_events_exit();
	quadd_auth_deinit();
	quadd_proc_deinit();
	quadd_unwind_deinit();

#ifdef CONFIG_ARM64
	quadd_armv8_pmu_deinit();
#else
	quadd_armv7_pmu_deinit();
#endif
}

module_init(quadd_module_init);
module_exit(quadd_module_exit);

MODULE_LICENSE("GPL");

MODULE_AUTHOR("Nvidia Ltd");
MODULE_DESCRIPTION("Tegra profiler");
