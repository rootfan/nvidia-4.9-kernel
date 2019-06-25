#!/system/bin/sh

partitions=
userdata=
runf2fs=0

# parsing parameter to find out interested partitions
while [ $# -gt 0 ]
do
    if [[ "$1" == "--data" ]]; then
        userdata=$2
        shift
    else
        partitions+=" $1"
    fi
    shift
done

if [[ "$userdata" != "" ]]; then
    fstype=$(getprop vold.fscheck.fstype)

    # userdata partition to partitions array if not f2fs
    # if not set to explicitly, it's ext4 by default
    if [[ "$fstype" != "1" ]]; then
        partitions+=" $userdata"
    else
        runf2fs=1
    fi
fi

f2fs_cmd="/system/bin/make_f2fs -l UDA $userdata"
ext4_cmd="/system/bin/setup_fs $partitions"

if [ $runf2fs -eq 1 ]; then
    $f2fs_cmd
fi

$ext4_cmd
