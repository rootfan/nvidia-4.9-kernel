old-dtb := $(dtb-y)
dtb-y :=
makefile-path := platform/t210/ers/kernel-dts

dtb-$(CONFIG_ARCH_TEGRA_210_SOC) += tegra210-ers-e2190-1100-a00-00.dtb
dtb-$(CONFIG_ARCH_TEGRA_210_SOC) += tegra210-ers-e2220-1170-a00-00.dtb
dtb-$(CONFIG_ARCH_TEGRA_210_SOC) += tegra210-ers-e2220-1170-a00-dp-00.dtb
dtb-$(CONFIG_ARCH_TEGRA_210_SOC) += tegra210-ers-e2220-1170-a00-01.dtb
dtb-$(CONFIG_ARCH_TEGRA_210_SOC) += tegra210-l4t-ers-e2220-1170-a00-00.dtb
dtb-$(CONFIG_ARCH_TEGRA_210_SOC) += tegra210-ers-e2220-1180-a00-00.dtb
dtb-$(CONFIG_ARCH_TEGRA_210_SOC) += tegra210-l4t-ers-e2220-1180-a00-00.dtb
dtb-$(CONFIG_ARCH_TEGRA_210_SOC) += tegra210-ers-e2220-1199-a00-00.dtb
dtb-$(CONFIG_ARCH_TEGRA_210_SOC) += tegra210-ers-p2143-1170-a00-00.dtb
dtb-$(CONFIG_ARCH_TEGRA_210_SOC) += tegra210-ers-p2143-1170-a00-01.dtb
dtb-$(CONFIG_ARCH_TEGRA_210_SOC) += tegra210-ers-p2143-1199-a00-00.dtb
dtb-$(CONFIG_ARCH_TEGRA_210_SOC) += tegra210-ers-p2143-1180-a00-00.dtb


ifneq ($(dtb-y),)
dtb-y := $(addprefix $(makefile-path)/,$(dtb-y))
dts-include += $(makefile-path)
endif

dtb-y += $(old-dtb)
