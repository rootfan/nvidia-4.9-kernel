old-dtb := $(dtb-y)
dtb-y :=
makefile-path := platform/t210/fpga/kernel-dts

dtb-$(CONFIG_ARCH_TEGRA_210_SOC) += tegra210b01-grenada.dtb

ifneq ($(dtb-y),)
dtb-y := $(addprefix $(makefile-path)/,$(dtb-y))
endif

dtb-y += $(old-dtb)
