#!/usr/bin/env bash
# Temiz idle güç tabanı — power.md yöntemi (120 s sakinleşme + 6×10 s örnek).
#
# NEDEN AYRI BİR SCRIPT: power-audit.sh envanter döker (ne açık, hangi ayar nerede);
# bu dosya tek bir sayı üretir ve o sayının HANGİ KOŞULDA alındığını yanına yazar.
# Ölçümün kendisi yükü değiştirmemeli, o yüzden döngü içinde fork yok: sayaçlar
# doğrudan okunuyor, çıktı sonda tek seferde basılıyor.
#
# KULLANIM: ekranı açık bırak, terminali gizle/başka workspace'e geç, DOKUNMA.
#   bash scripts/idle-baseline.sh > /tmp/idle.txt
set -u

B=/sys/class/power_supply/BAT1
G=/sys/class/drm/card1/device/gpu_busy_percent
P=/sys/kernel/debug/dri/0000:65:00.0/eDP-1/psr_residency

read_w() { printf '%s %s' "$(cat $B/current_now)" "$(cat $B/voltage_now)"; }

SETTLE=${SETTLE:-120}
sleep "$SETTLE"

fork0=$(awk '/^processes/{print $2}' /proc/stat)
gpu_s=0; gpu_n=0
declare -a SAMP
for i in $(seq 1 6); do
  set -- $(read_w); SAMP+=("$1 $2")
  g=$(cat $G 2>/dev/null || echo 0); gpu_s=$((gpu_s+g)); gpu_n=$((gpu_n+1))
  sleep 10
done
fork1=$(awk '/^processes/{print $2}' /proc/stat)

# --- rapor ---
echo "tarih      : $(date -Is)"
echo "oturum     : ${XDG_SESSION_DESKTOP:-?} / ${XDG_CURRENT_DESKTOP:-?}"
echo "AC online  : $(cat /sys/class/power_supply/ACAD/online)"
echo "parlaklık  : $(cat /sys/class/backlight/amdgpu_bl1/brightness)/$(cat /sys/class/backlight/amdgpu_bl1/max_brightness)"
echo "profil     : $(cat /sys/firmware/acpi/platform_profile) / $(cat /sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference)"
echo "fan_mode   : $(cat $(echo /sys/bus/wmi/devices/ABBC0F75-*/fan_mode) 2>/dev/null || echo -)"
echo "fork/s     : $(( (fork1-fork0) / 60 ))"
echo "gpu_busy   : $(( gpu_s / gpu_n ))%"
echo "psr_res    : $(cat $P 2>/dev/null || echo '(root gerek)')"
printf 'örnekler   :'
tot=0
for s in "${SAMP[@]}"; do
  set -- $s
  w=$(awk -v c="$1" -v v="$2" 'BEGIN{printf "%.2f", c*v/1e12}')
  printf ' %s' "$w"
  tot=$(awk -v t="$tot" -v w="$w" 'BEGIN{print t+w}')
done
echo
# power.md kararı ORTALAMAYA değil MİNİMUMA dayanır: arka planda bir şey uyanınca
# maksimum 12 W'a fırlayıp ortalamayı çeker, taban yerinde kalır. Yayılım da
# raporlanır çünkü kalite göstergesi odur — temiz koşu 0.67-0.85 W, kirli 3.2-7.5 W.
{ for s in "${SAMP[@]}"; do set -- $s; awk -v c="$1" -v v="$2" 'BEGIN{printf "%.4f\n", c*v/1e12}'; done; } |
  awk '{ t+=$1; if(NR==1||$1<mn) mn=$1; if(NR==1||$1>mx) mx=$1 }
       END{ printf "ORTALAMA   : %.2f W\n", t/NR;
             printf "MİNİMUM    : %.2f W   <- power.md bu sayıya bakar\n", mn;
             printf "MAKSİMUM   : %.2f W\n", mx;
             s = mx-mn;
             printf "YAYILIM    : %.2f W   (%s)\n", s,
                    (s<=0.9 ? "TEMİZ - sayı kullanılabilir" : "KİRLİ - arka planda iş var, minimuma bak") }'
