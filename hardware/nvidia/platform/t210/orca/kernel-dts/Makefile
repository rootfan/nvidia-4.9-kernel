old-dtb := $(dtb-y)
dtb-y :=
makefile-path := platform/t210/orca/kernel-dts

dtb-$(CONFIG_ARCH_TEGRA_210_SOC) += tegra210-m3402-0000-a00-00.dtb
dtb-$(CONFIG_ARCH_TEGRA_210_SOC) += tegra210-m3402-0000-a00-00-e2603.dtb
dtb-$(CONFIG_ARCH_TEGRA_210_SOC) += tegra210-m3402-0000-a00-00-e2606.dtb

ifneq ($(dtb-y),)
dtb-y := $(addprefix $(makefile-path)/,$(dtb-y))
endif

dtb-y += $(old-dtb)
