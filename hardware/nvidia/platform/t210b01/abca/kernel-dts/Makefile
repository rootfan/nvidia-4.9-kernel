old-dtb := $(dtb-y)
dtb-y :=
makefile-path := platform/t210b01/abca/kernel-dts

dts-include += platform/t210/common/kernel-dts
dts-include += $(makefile-path)

dtb-$(CONFIG_ARCH_TEGRA_210_SOC) += tegra210b01-abca-01-00.dtb
dtb-$(CONFIG_ARCH_TEGRA_210_SOC) += tegra210b01-abca-01-10.dtb

ifneq ($(dtb-y),)
dtb-y := $(addprefix $(makefile-path)/,$(dtb-y))
endif

dtb-y += $(old-dtb)
