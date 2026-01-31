#!/usr/bin/env bash
# Gigabyte ACPI Power Profile Finder
# Bu script Gigabyte laptoplarda GPU power profile ACPI method'larını bulur

set -e

echo "================================================"
echo "Gigabyte ACPI Power Profile Method Finder"
echo "================================================"
echo ""

# Check if acpi_call module is loaded
if ! lsmod | grep -q acpi_call; then
    echo "[!] acpi_call modülü yüklü değil!"
    echo "    Yükleniyor..."
    sudo modprobe acpi_call
fi

echo "[✓] acpi_call modülü yüklü"
echo ""

# Check if /proc/acpi/call exists
if [ ! -f /proc/acpi/call ]; then
    echo "[!] /proc/acpi/call bulunamadı!"
    exit 1
fi

echo "[*] ACPI tablosu taranıyor..."
echo ""

# Common Gigabyte ACPI paths for power profiles
ACPI_PATHS=(
    "\_SB.PCI0.LPCB.EC0.VPC0.DYTC"    # Lenovo style
    "\_SB.PCI0.LPC0.EC0.VPC0.DYTC"    # Lenovo variant
    "\_SB.ATKD.WMNB"                   # ASUS style
    "\_SB.WMI.WMBA"                    # Generic WMI
    "\_SB.WMI.WMBB"                    # Generic WMI B
    "\_SB.PCI0.SBRG.EC0._Q80"          # EC Query
    "\_SB.PC00.LPCB.EC0"               # EC direct
    "\_SB.PCI0.LPCB.EC0"               # EC direct variant
    "\_SB.WMID.WSPF"                   # Gigabyte specific
    "\_SB.WMID.WMAX"                   # Gigabyte WMAX
    "\_SB.AMW0.WMBC"                   # AMW WMI
    "\_SB.PCI0.PEG0.PEGP.SGOF"         # GPU Off
    "\_SB.PCI0.PEG0.PEGP.SGON"         # GPU On
    "\_SB.PCI0.PEG0.PEGP._ON"          # GPU Power On
    "\_SB.PCI0.PEGP"                   # PCI Express GPU
    "\_SB.PCI0.GFX0"                   # Integrated GPU
    "\_SB_.PCI0.GPP0.PEGP"             # AMD GPU path
    "\_SB_.PCI0.GP17.VGA"              # AMD iGPU
    "\_GPE._E00"                       # GPE Event
)

echo "Bilinen ACPI path'leri test ediliyor..."
echo ""

for path in "${ACPI_PATHS[@]}"; do
    # Try to call the method with no arguments
    echo "$path" | sudo tee /proc/acpi/call > /dev/null 2>&1
    result=$(sudo cat /proc/acpi/call 2>/dev/null || echo "ERROR")
    
    if [[ "$result" != *"Error"* ]] && [[ "$result" != "ERROR" ]] && [[ "$result" != "" ]]; then
        echo "[✓] BULUNDU: $path"
        echo "    Sonuç: $result"
    fi
done

echo ""
echo "================================================"
echo "ACPI DSDT tablosundan method'lar aranıyor..."
echo "================================================"
echo ""

# Dump and analyze ACPI tables
if [ -f /sys/firmware/acpi/tables/DSDT ]; then
    echo "[*] DSDT tablosu analiz ediliyor..."
    
    # Look for Gigabyte-specific strings in DSDT
    sudo cat /sys/firmware/acpi/tables/DSDT | strings | grep -i -E "giga|aero|power|perf|turbo|boost|wmax|wmid" | head -20 || echo "    Spesifik string bulunamadı"
    
    echo ""
    echo "[*] WMI GUID'leri kontrol ediliyor..."
    ls /sys/bus/wmi/devices/ 2>/dev/null || echo "    WMI cihazları bulunamadı"
fi

echo ""
echo "================================================"
echo "Platform Profile Durumu"
echo "================================================"
cat /sys/firmware/acpi/platform_profile 2>/dev/null || echo "Platform profile yok"
cat /sys/firmware/acpi/platform_profile_choices 2>/dev/null || echo ""

echo ""
echo "================================================"
echo "EC Register Dump (ilk 256 byte)"
echo "================================================"
if [ -f /sys/kernel/debug/ec/ec0/io ]; then
    sudo xxd /sys/kernel/debug/ec/ec0/io | head -16
else
    echo "EC debug erişimi yok"
fi

echo ""
echo "Bitti!"
