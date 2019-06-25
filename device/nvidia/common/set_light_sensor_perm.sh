#!/system/bin/sh
#
# Copyright (c) 2013-2014, NVIDIA CORPORATION.  All rights reserved.
#
/system/bin/chown system:system /sys/bus/iio/devices/iio:device*/in_illuminance_enable
/system/bin/chown system:system /sys/bus/iio/devices/iio:device*/in_illuminance_regulator_enable
/system/bin/chown system:system /sys/bus/iio/devices/iio:device*/in_illuminance_raw
/system/bin/chmod 0600 /sys/bus/iio/devices/iio:device*/in_illuminance_enable
/system/bin/chmod 0600 /sys/bus/iio/devices/iio:device*/in_illuminance_regulator_enable
/system/bin/chown system:system /sys/bus/iio/devices/iio:device*/in_proximity_enable
/system/bin/chown system:system /sys/bus/iio/devices/iio:device*/in_proximity_regulator_enable
/system/bin/chown system:system /sys/bus/iio/devices/iio:device*/in_proximity_raw
/system/bin/chmod 0600 /sys/bus/iio/devices/iio:device*/in_proximity_enable
/system/bin/chmod 0600 /sys/bus/iio/devices/iio:device*/in_proximity_regulator_enable


# LTR659 sensor permission

/system/bin/chown system:system /sys/bus/iio/devices/iio:device*/proximity_enable
/system/bin/chmod 0600 /sys/bus/iio/devices/iio:device*/proximity_enable
