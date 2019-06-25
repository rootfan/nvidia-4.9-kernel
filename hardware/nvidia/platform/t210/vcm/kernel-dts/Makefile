old-dtb := $(dtb-y)
dtb-y :=
makefile-path := platform/t210/vcm/kernel-dts

dtb-$(CONFIG_ARCH_TEGRA_210_SOC) += tegra210-vcm31-e2580-0631-a00-00.dtb
dtb-$(CONFIG_ARCH_TEGRA_210_SOC) += tegra210-vcm31-e2580-0631-a00-00-vm.dtb
dtb-$(CONFIG_ARCH_TEGRA_210_SOC) += tegra210-vcm31-e2580-0631-a00-00-vm1.dtb
dtb-$(CONFIG_ARCH_TEGRA_210_SOC) += tegra210-vcm31-e2580-0631-a00-00-vm2.dtb
dtb-$(CONFIG_ARCH_TEGRA_210_SOC) += tegra210-vcm31-e2379.dtb
dtb-$(CONFIG_ARCH_TEGRA_210_SOC) += tegra210-vcm31-p2382-0000-a00-00.dtb
dtb-$(CONFIG_ARCH_TEGRA_210_SOC) += tegra210-vcm31-p2382-0000-a00-00-vm.dtb
dtb-$(CONFIG_ARCH_TEGRA_210_SOC) += tegra210-vcm31-p2382-0000-a00-00-vm1.dtb
dtb-$(CONFIG_ARCH_TEGRA_210_SOC) += tegra210-vcm31-p2382-0000-a00-00-vm2.dtb
dtb-$(CONFIG_ARCH_TEGRA_210_SOC) += tegra210-vcm31-p2382-0000-a00-00-hdmi-primary.dtb
dtb-$(CONFIG_ARCH_TEGRA_210_SOC) += tegra210-vcm31-p2382-0000-a00-00-p2393-1080p.dtb
dtb-$(CONFIG_ARCH_TEGRA_210_SOC) += tegra210-vcm31-p2382-0000-a00-00-p2393-25x16.dtb
dtb-$(CONFIG_ARCH_TEGRA_210_SOC) += tegra210-vcm31-e2379-0000-b00-00-a.dtb
dtb-$(CONFIG_ARCH_TEGRA_210_SOC) += tegra210-vcm31-e2379-0000-b00-00-b.dtb
dtb-$(CONFIG_ARCH_TEGRA_210_SOC) += tegra210-vcm31-flashing-kernel.dtb
dtb-$(CONFIG_ARCH_TEGRA_210_SOC) += tegra210-vcm31-maui.dtb

ifneq ($(dtb-y),)
dtb-y := $(addprefix $(makefile-path)/,$(dtb-y))
endif

dtb-y += $(old-dtb)
