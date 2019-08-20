#!/system/bin/sh

################################################################################
# helper functions to allow Android init like script

function write() {
    echo -n $2 > $1
}

function copy() {
    cat $1 > $2
}
################################################################################
if [ ! -f /data/property/persist.spectrum.profile ]; then
    setprop persist.spectrum.profile 1
fi
{

sleep 10

# Disable MSM Thermal Driver
write /sys/module/msm_thermal/parameters/enabled "N"

# Low memory killer
# write /sys/module/lowmemorykiller/parameters/minfree "9466,14199,28398,47330,66262,70995"

# Governor
chmod 0644 /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
chmod 0644 /sys/devices/system/cpu/cpu4/cpufreq/scaling_governor
# chmod 0644 /sys/devices/system/cpu/cpu0/cpufreq/interactive/*
# chmod 0644 /sys/devices/system/cpu/cpu4/cpufreq/interactive/*



# VM Tweaks
write /proc/sys/vm/laptop_mode 1
write /proc/sys/vm/swappiness 60
write /proc/sys/vm/vfs_cache_pressure 100
# write /proc/sys/vm/vm_dirty_ratio 50
write /proc/sys/vm/dirty_background_ratio 20

# I/O Scheduler
setprop sys.io.scheduler "deadline"
write /sys/block/mmcblk0/queue/read_ahead_kb 2048

sleep 20

}&
