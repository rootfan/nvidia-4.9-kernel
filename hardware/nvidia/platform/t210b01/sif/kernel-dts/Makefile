old-dtb := $(dtb-y)
dtb-y :=
makefile-path := platform/t210b01/sif/kernel-dts

dts-include += platform/t210/foster/kernel-dts
dts-include += platform/t210/common/kernel-dts
dts-include += platform/t210b01/ers/kernel-dts
dts-include += $(makefile-path)

dtb-$(CONFIG_ARCH_TEGRA_210_SOC) += tegra210b01-sif-p3425-0000-a00.dtb

ifneq ($(dtb-y),)
dtb-y := $(addprefix $(makefile-path)/,$(dtb-y))
endif

dtb-y += $(old-dtb)
