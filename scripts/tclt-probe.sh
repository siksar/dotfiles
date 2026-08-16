#!/usr/bin/env bash
# tclt-probe.sh — \DPTT(0x03, N) termal setpoint hipotezini ÖLÇER.
#
# Hipotez: DSDT'de _Q20 -> DPTT(0x03, TCLT) -> \_SB.ALIB(0x0C) [AMD DPTC] zinciri,
# SMU'ya Tctl hedefini bildiren yoldur; TCLT@0x8C = 95 de o hedefin sayisidir.
# Bu betik hipotezi CALISTIRARAK sinar. Masa basi cikarim kanit degildir.
#
# TASARIM — neden "sabit yuk altinda basamak" (staircase), ayri kosular degil:
#   Ayri kosularda ortam sicakligi/termal birikim kollar arasi kayar ve farki taklit
#   eder. Burada yuk hic durmadan devam ederken setpoint kademe kademe dusurulur;
#   Tctl'in AYNI kosu icinde basamaga inip geri cikmasi tek basina kanittir.
#
# GUVENLIK:
#   - YALNIZ ASAGI YON. N > 95 reddedilir (termal koruma sinirini yukari oynatmak yok).
#   - Her kolun sonunda ve trap'te 95 ACIKCA geri yazilir.
#   - acpi_call disinda hicbir EC selector'une yazilmaz (gpu_boost/0x51/0x4B/0xF1-F3'e
#     DOKUNULMAZ).
#   - Frekans tavani gecici degistirilirse trap ile geri konur.
#
# Kullanim:  sudo bash scripts/tclt-probe.sh capped     # hafif, kesin islevsellik testi
#            sudo bash scripts/tclt-probe.sh uncapped   # takas tablosu (makine isinir)
set -u

MODE="${1:-capped}"
BURN="${BURN:-}"
OUT="${OUT:-/tmp/tclt-probe}"
mkdir -p "$OUT"

# ---------------------------------------------------------------- on kosullar
[ "$(id -u)" -eq 0 ] || { echo "HATA: root gerekiyor (sudo ile calistir)."; exit 1; }
[ -w /proc/acpi/call ] || { echo "HATA: /proc/acpi/call yok — acpi_call modulu yuklu mu?"; exit 1; }

AC=$(cat /sys/class/power_supply/ACAD/online)
[ "$AC" = "1" ] || { echo "HATA: AC bagli degil (ACAD/online=$AC). Fisi tak, tekrar dene."; exit 1; }

FANMODE=$(cat /sys/devices/platform/aorus_laptop/fan_mode 2>/dev/null || echo "?")
echo "on kosul: AC=1, fan_mode=$FANMODE (olcum boyunca sabit kalmali)"

K=""; A=""
for h in /sys/class/hwmon/hwmon*; do
  n=$(cat "$h/name" 2>/dev/null) || continue
  [ "$n" = "k10temp" ] && K="$h"
  [ "$n" = "amdgpu" ]  && A="$h"
  [ "$n" = "aorus_laptop" ] && AO="$h"
done
[ -n "$K" ] && [ -n "$A" ] || { echo "HATA: k10temp/amdgpu hwmon bulunamadi."; exit 1; }
echo "hwmon: k10temp=$K amdgpu=$A aorus=${AO:-yok}"

[ -n "$BURN" ] && [ -x "$BURN" ] || { echo "HATA: BURN=<avx512 yuk ikilisi> verilmeli."; exit 1; }

CAP_ORIG=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq)
CPUMAX=$(cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq)

# ------------------------------------------------------------------ yardimci
TCLT_ADDR=$((0xFC7E0800 + 0x8C))
read_tclt() {  # EC'nin kendi TCLT baytini oku (bizim yazdigimiz SMU degeri DEGIL)
  local v
  v=$(dd if=/dev/mem bs=1 count=1 skip=$TCLT_ADDR iflag=skip_bytes 2>/dev/null | od -An -tu1 | tr -d ' \n')
  [ -n "$v" ] && echo "$v" || echo "?"
}
gpe_count() { cat /sys/firmware/acpi/interrupts/gpe0A 2>/dev/null | awk '{print $1}'; }

dptt() {  # dptt N  -> \DPTT(0x03, N)
  local n="$1"
  if [ "$n" -gt 95 ]; then echo "GUVENLIK: N=$n > 95 reddedildi"; return 1; fi
  echo "\\DPTT 0x03 $n" > /proc/acpi/call
  local r; r=$(tr -d '\0' < /proc/acpi/call)
  echo "$r"
}

set_cap() {
  local v="$1"
  for c in /sys/devices/system/cpu/cpu*/cpufreq; do
    [ -w "$c/scaling_max_freq" ] && echo "$v" > "$c/scaling_max_freq" 2>/dev/null
  done
}

LOADPIDS=()
cleanup() {
  echo
  echo "-- temizlik --"
  for p in "${LOADPIDS[@]:-}"; do kill "$p" 2>/dev/null; done
  echo "  setpoint 95 geri yaziliyor: $(dptt 95)"
  if [ "$MODE" = "uncapped" ]; then
    set_cap "$CAP_ORIG"
    echo "  frekans tavani geri: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq) (orijinal $CAP_ORIG)"
  fi
  echo "  EC TCLT@0x8C = $(read_tclt)  (EC'nin kendi degeri; 95 olmali)"
  echo "  fan_mode = $(cat /sys/devices/platform/aorus_laptop/fan_mode 2>/dev/null)"
}
trap cleanup EXIT INT TERM

# ------------------------------------------------------- 0) DPTT varlik probu
echo
echo "== 0) \\DPTT probu =="
echo "  EC TCLT@0x8C (yazmadan once) = $(read_tclt)"
PROBE=$(dptt 95)   # 95 = mevcut deger, no-op; sadece cagri calisiyor mu diye
echo "  \\DPTT(0x03,95) -> '$PROBE'"
case "$PROBE" in
  *Error*|*error*|*not*found*) echo "  !! DPTT cagrilamadi. Hipotez BU ADIMDA duser."; exit 1;;
  *) echo "  cagri hatasiz dondu (DPTT her zaman 0 doner; bu 'etki etti' demek DEGIL).";;
esac

# ------------------------------------------------------------- yuk + ornekleme
start_load() {
  local nt="$1" dur="$2" cpus
  case "$nt" in
    4)  cpus="0 2 4 6";;
    16) cpus="0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15";;
  esac
  LOADPIDS=()
  for c in $cpus; do
    taskset -c "$c" "$BURN" "$dur" >/dev/null 2>&1 &
    LOADPIDS+=($!)
  done
}

# staircase <csv> <toplam_sn> <"sn:N sn:N ...">
staircase() {
  local csv="$1" total="$2" steps="$3"
  : > "$csv"
  echo "t_s,tctl_mC,ppt_uW,khz,rpm,setpoint,gpe0A,tclt_ec" >> "$csv"
  local cur=95
  local g0; g0=$(gpe_count)
  local i n=$((total*2))
  for ((i=0;i<n;i++)); do
    local t=$((i/2)) sub=$((i%2))
    # bu saniyede bir basamak var mi?
    if [ "$sub" -eq 0 ]; then
      for s in $steps; do
        local at="${s%%:*}" val="${s##*:}"
        if [ "$at" -eq "$t" ]; then
          local r; r=$(dptt "$val")
          cur="$val"
          echo "  [t=${t}s] setpoint -> $val   (\\DPTT dondu: $r)"
        fi
      done
    fi
    local tc pw kh rp
    tc=$(cat "$K/temp1_input"); pw=$(cat "$A/power1_input")
    kh=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq)
    rp=$(cat "${AO:-/nonexist}/fan1_input" 2>/dev/null || echo 0)
    echo "$t.$((sub*5)),$tc,$pw,$kh,$rp,$cur,$(( $(gpe_count) - g0 )),$(read_tclt)" >> "$csv"
    sleep 0.5
  done
}

# pencere ortalamasi: son W saniye
mean_window() {
  local csv="$1" from="$2" to="$3"
  awk -F, -v a="$from" -v b="$to" 'NR>1 && $1>=a && $1<b {
      n++; t+=$2; p+=$3; f+=$4; r+=$5; sp=$6; g=$7; ec=$8
    } END {
      if(n==0){print "veri yok"; exit}
      printf "%-3s  %6.2f C  %6.2f W  %6.0f MHz  %5.0f RPM   (n=%d, gpe+%d, ecTCLT=%s)\n",
             sp, t/n/1000, p/n/1000000, f/n/1000, r/n, n, g, ec
    }' "$csv"
}

# =============================================================== KOL 1: capped
if [ "$MODE" = "capped" ]; then
  echo
  echo "== 1) ISLEVSELLIK TESTI (tavan yerinde, hafif) =="
  echo "   Makine bu rejimde ~73 C'de oturuyor (tavan-limitli, termal degil)."
  echo "   Setpoint'i 70'e cekiyoruz: DPTT calisiyorsa Tctl 70'e INMELI."
  echo "   Yuk: 16 thread AVX-512, 150 s kesintisiz."
  CSV="$OUT/capped.csv"
  start_load 16 160
  echo "   (yuk basladi, 8 s oturma payi)"; sleep 8
  # 0-40 taban(95) | 40-90 setpoint 70 | 90-140 geri 95
  staircase "$CSV" 140 "40:70 90:95"
  for p in "${LOADPIDS[@]}"; do kill "$p" 2>/dev/null; done; LOADPIDS=()
  echo
  echo "   -- kararli pencereler (her basamagin son 15 s'i) --"
  printf "   %-3s  %8s  %8s  %9s  %8s\n" "SP" "Tctl" "PPT" "Saat" "Fan"
  printf "   taban  "; mean_window "$CSV" 25 40
  printf "   set70  "; mean_window "$CSV" 75 90
  printf "   geri   "; mean_window "$CSV" 125 140
  echo
  echo "   CSV: $CSV"
fi

# ============================================================= KOL 2: uncapped
if [ "$MODE" = "uncapped" ]; then
  echo
  echo "== 2) TAKAS TABLOSU (tavan gecici KALKIK — makine isinir/sesli olur) =="
  echo "   Gerekce: 4.5 GHz tavani yerindeyken CPU termal duvara HIC ulasmiyor"
  echo "   (16 thread'de bile ~73.5 C). TCLT ancak makine termal-limitliyken baglar;"
  echo "   o rejim de tam olarak oyun rejimidir (game-perf tavani kaldirir)."
  set_cap "$CPUMAX"
  echo "   tavan: $CAP_ORIG -> $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq)"
  CSV="$OUT/uncapped.csv"
  start_load 16 220
  echo "   (yuk basladi, 10 s oturma payi)"; sleep 10
  # 0-50 taban(95) | 50-100 -> 90 | 100-150 -> 85 | 150-200 -> 95 (geri)
  staircase "$CSV" 200 "50:90 100:85 150:95"
  for p in "${LOADPIDS[@]}"; do kill "$p" 2>/dev/null; done; LOADPIDS=()
  echo
  echo "   -- kararli pencereler (her basamagin son 20 s'i) --"
  printf "   %-3s  %8s  %8s  %9s  %8s\n" "SP" "Tctl" "PPT" "Saat" "Fan"
  printf "   N=95   "; mean_window "$CSV" 30 50
  printf "   N=90   "; mean_window "$CSV" 80 100
  printf "   N=85   "; mean_window "$CSV" 130 150
  printf "   N=95'  "; mean_window "$CSV" 180 200
  echo
  echo "   CSV: $CSV"
fi

echo
echo "== bitti =="
