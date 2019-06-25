/*
 * Copyright (c) 2014, NVIDIA Corporation.  All Rights Reserved.
 *
 * NVIDIA Corporation and its licensors retain all intellectual property and
 * proprietary rights in and to this software and related documentation.  Any
 * use, reproduction, disclosure or distribution of this software and related
 * documentation without an express license agreement from NVIDIA Corporation
 * is strictly prohibited.
 */

#include <healthd/healthd.h>

void healthd_board_init(struct healthd_config *config)
{
    // use defaults
}

int healthd_board_battery_update(struct android::BatteryProperties *props)
{
    // return non-zero to prevent logging polled battery status to kernel log
	return 1;
}
