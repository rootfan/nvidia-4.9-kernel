old-dtb := $(dtb-y)
dtb-y :=
makefile-path := platform/t210b01/ers/kernel-dts

dts-include += platform/t210/common/kernel-dts
dts-include += $(makefile-path)

dtb-$(CONFIG_ARCH_TEGRA_210_SOC) += tegra210b01-ers-e3350-1000-a00-00-base.dtb
dtb-$(CONFIG_ARCH_TEGRA_210_SOC) += tegra210b01-ers-e3350-1000-dp-a00-00-base.dtb
dtb-$(CONFIG_ARCH_TEGRA_210_SOC) += tegra210b01-ers-e3350-1000-char-a00-00-base.dtb
dtb-$(CONFIG_ARCH_TEGRA_210_SOC) += tegra210b01-ers-e3350-1099-a00-00-base.dtb
dtb-$(CONFIG_ARCH_TEGRA_210_SOC) += tegra210b01-ers-e3350-1099-dp-a00-00-base.dtb
dtb-$(CONFIG_ARCH_TEGRA_210_SOC) += tegra210b01-ers-e3350-1099-char-a00-00-base.dtb

ifneq ($(dtb-y),)
dtb-y := $(addprefix $(makefile-path)/,$(dtb-y))
endif

dtb-y += $(old-dtb)
