#!/usr/bin/env bash

set -euo pipefail

OUT="power-audit-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$OUT"

echo "===== Linux Power Audit ====="

save(){
    echo "Collecting $1..."
    eval "$2" > "$OUT/$1.txt" 2>&1 || true
}

############################
# Basic
############################

save os-release "cat /etc/os-release"
save uname "uname -a"
save cmdline "cat /proc/cmdline"

############################
# CPU
############################

save cpuinfo "lscpu"
save cpu_extended "lscpu --extended"

save amd_pstate_status \
"cat /sys/devices/system/cpu/amd_pstate/status"

save governor \
"cat /sys/devices/system/cpu/cpufreq/policy0/scaling_governor"

save scaling_driver \
"cat /sys/devices/system/cpu/cpufreq/policy0/scaling_driver"

save epp \
"cat /sys/devices/system/cpu/cpufreq/policy0/energy_performance_preference"

save cpuidle_names \
"cat /sys/devices/system/cpu/cpu0/cpuidle/state*/name"

save cpuidle_usage \
"cat /sys/devices/system/cpu/cpu0/cpuidle/state*/usage"

save cpuidle_time \
"cat /sys/devices/system/cpu/cpu0/cpuidle/state*/time"

############################
# Kernel
############################

save modules "lsmod"

save dmesg \
"dmesg | grep -Ei 'amd|acpi|firmware|pcie|nvme|nvidia|pm'"

save journal \
"journalctl -b | grep -Ei 'amd|acpi|firmware|pcie|nvme|nvidia|pm'"

############################
# PCI
############################

save lspci "lspci -nn"

save lspci_vv "lspci -vv"

############################
# USB
############################

save lsusb "lsusb"

save usb_autosuspend \
"cat /sys/module/usbcore/parameters/autosuspend"

############################
# NVMe
############################

save lsblk \
"lsblk -o NAME,SIZE,MODEL,FSTYPE,MOUNTPOINT"

save nvme_list \
"nvme list"

save nvme_apst \
"nvme get-feature /dev/nvme0 -f 0x0c -H"

############################
# Firmware
############################

save bios \
"dmidecode -t bios"

save system \
"dmidecode -t system"

save fwupd_devices \
"fwupdmgr get-devices"

save fwupd_updates \
"fwupdmgr get-updates"

############################
# Power
############################

save mem_sleep \
"cat /sys/power/mem_sleep"

save power_profiles \
"powerprofilesctl"

save battery \
"upower -i \$(upower -e | grep BAT)"

############################
# Scheduler
############################

save scheduler \
"cat /sys/block/nvme0n1/queue/scheduler"

save clocksource \
"cat /sys/devices/system/clocksource/clocksource0/current_clocksource"

############################
# Interrupts
############################

save interrupts \
"cat /proc/interrupts"

############################
# Runtime PM
############################

find /sys/bus/pci/devices -name runtime_status \
-exec sh -c 'echo "### {}";cat "{}"' \; \
> "$OUT/runtime_pm.txt" 2>/dev/null || true

############################
# Powertop
############################

if command -v powertop >/dev/null
then
    timeout 120 powertop --html="$OUT/powertop.html" || true
fi

############################
# Powerstat
############################

if command -v powerstat >/dev/null
then
    powerstat -R 1 60 > "$OUT/powerstat.txt" || true
fi

############################
# Summary
############################

echo "Done."

echo ""
echo "Files written to:"
echo "$OUT"
