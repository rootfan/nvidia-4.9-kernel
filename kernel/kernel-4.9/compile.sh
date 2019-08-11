#!/bin/bash
boot_maker()
{
bootdir="/home/derek/Downloads/android_bootimg_tools/shield_dev"
cp ./out/arch/arm64/boot/zImage $bootdir && echo "zImage copied!"
cd $bootdir

if ../mkbootimg --kernel zImage --ramdisk boot_dev.img-ramdisk.gz  --base 10000000 --pagesize 2048 -o shieldtv_boot.img 
then
read -p "flash? " flash

if [ $flash = "y" ]
then
[[ $(adb devices) = *"device"* ]] && adb reboot bootloader
sudo /home/derek/Android/Sdk/platform-tools/fastboot oem dtbname
sleep 3
sudo /home/derek/Android/Sdk/platform-tools/fastboot flash boot shieldtv_boot.img
sudo /home/derek/Android/Sdk/platform-tools/fastboot reboot
cd $startdir
fi

else
echo "failed to make boot.img!"

fi
}

module_sender()
{
read -p "send modules? " send
if [ $send = 'y' ] 
then
adb reboot recovery
while [[ $(adb devices) != *"recovery"* ]]
do
sleep 1
done
adb shell twrp mount vendor
#adb push ./out/drivers/gpu/nvgpu/nvgpu.ko /vendor/lib/modules
adb push ./out/drivers/devfreq/governor_pod_scaling.ko /vendor/lib/modules
adb reboot $1
fi
}


# main
startdir=$(pwd)

export CROSS_COMPILE="/media/derek/10KHDD/aarch64-linux-gnu-6.4.1-2017.08/bin/aarch64-linux-gnu-"
export ARCH="arm64"
export SUBARCH="arm64"

if  [ ! -d ./out ]
then
mkdir out
make O=out clean
make O=out mrproper
make O=out tegra_android_defconfig
fi

if make O=out -j8
then
echo "Compile succeeded!"
#module_sender bootloader
boot_maker
else
echo "Compile failed!"
fi



