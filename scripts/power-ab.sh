#!/usr/bin/env bash
# Çalışma anında değiştirilebilen güç kollarının A/B ölçümü (pilde, boşta).
#
# Her kol için A = mevcut durum, B = aday. Kollar ABBA sırasıyla ölçülür:
# doğrusal sapma (pil voltajı düşüşü, ısınma) iki kolda eşit dağılır. Her
# koldan sonra S saniye sakinleşme, sonra M saniye ölçüm. Sonda HER ŞEY A'ya
# döner (EXIT tuzağı da döndürür).
#
# ÖLÇÜM PENCERESİNDE fork YOK, çıktı YOK (psr-idle-watts.sh ile aynı kural):
# bekleme `read -t`, watt saf bash tamsayısı (µA × µV / 1e6 = µW).
#
# KULLANIM (fişsiz, ekran statik, dokunmadan):
#   sudo bash scripts/power-ab.sh                    # tüm kollar
#   sudo KNOBS="cpuidle dpm" M=60 bash scripts/power-ab.sh
# Sonuç: $OUT (varsayılan /tmp/power-ab.txt) ve stdout.
#
# Kollar:
#   cpuidle   menu ↔ teo                       (cpuidle yöneticisi)
#   preempt   full ↔ voluntary                 (PREEMPT_DYNAMIC, debugfs)
#   kbdusb    dahili klavye autosuspend on ↔ auto (xHCI 67:00.0 uyuyabilsin)
#   irqpack   IRQ + unbound iş kuyruğu + unbound kthread → Zen5c (1,3,…,15)
#   dpm       iGPU power_dpm_force_performance_level auto ↔ low
#   vrr       Hyprland misc:vrr mevcut ↔ 0     (bilgi; kalıcı ayar kullanıcıda)
#   vrr3      misc:vrr 0 ↔ 3 (yalnız tam ekran + video/oyun içerik türü) — PSR korunuyor mu
#   cdfreeze  Claude Desktop cgroup'u çalışıyor ↔ donmuş (tepside bekleme bedeli)
#   cvfreeze  sesli asistan Chromium'u çalışıyor ↔ donmuş
#
# Ayrıştırma kolları (B = o bileşen yok; Δ onun bedeli):
#   dpms      ekran açık ↔ DPMS kapalı (panel + arka ışık + ekran hattı)
#   bright    parlaklık mevcut ↔ %1 (arka ışığın payı)
#   wifi      Wi-Fi açık ↔ rfkill (radyo + rtw89)
#   apps      kullanıcı birimleri çalışıyor ↔ donmuş (bu betiğin zinciri ve
#             Hyprland hariç: Claude Desktop, sesli asistan, waybar, syncthing…)
#   floor     dpms + wifi + apps birlikte → SoC + RAM + NVMe + EC tabanı
#
# PRE_VRR=0: ölçüm boyunca Hyprland misc:vrr bu değerde tutulur (sonda geri
# döner). VRR açıkken PSR hiç devreye girmiyor (4 Eki 2026) — öbür kolları PSR'lı
# rejimde ölçmek için.
set -u
PATH=/run/wrappers/bin:/run/current-system/sw/bin:$PATH

[[ $EUID == 0 ]] || { echo "root gerekli (sudo)" >&2; exit 1; }

KNOBS=${KNOBS:-"cpuidle preempt kbdusb irqpack dpm vrr cdfreeze cvfreeze"}
M=${M:-50}; S=${S:-12}; LEAD=${LEAD:-45}; ORDER=${ORDER:-"A B B A"}
OUT=${OUT:-/tmp/power-ab.txt}
USERNAME=${USERNAME_AB:-zixar}
UIDN=$(id -u "$USERNAME")
ZEN5C=1,3,5,7,9,11,13,15; ZEN5C_HEX=aaaa

BAT=/sys/class/power_supply/BAT1
PSR=/sys/kernel/debug/dri/0000:65:00.0/eDP-1/psr_state
DGPU=/sys/bus/pci/devices/0000:64:00.0/power/runtime_status

read -r ac < /sys/class/power_supply/ACAD/online
[[ $ac == 0 ]] || { echo "HATA: fiş takılı — current_now tüketimi göstermez" >&2; exit 1; }

exec {NAP}< <(exec tail -f /dev/null)
nap() { read -t "$1" -u "$NAP" _ 2>/dev/null || true; }

# ---- kollar: k_<ad> init|A|B ------------------------------------------------
# init başarısızsa kol atlanır.

k_cpuidle() {
  local g=/sys/devices/system/cpu/cpuidle/current_governor
  case $1 in
    init) read -r CPUIDLE_ORIG < $g; [[ $CPUIDLE_ORIG == menu ]] ;;
    A) echo "$CPUIDLE_ORIG" > $g ;;
    B) echo teo > $g ;;
  esac
}

k_preempt() {
  local f=/sys/kernel/debug/sched/preempt
  case $1 in
    init)
      [[ -w $f ]] || return 1
      local opts; read -r opts < $f
      PREEMPT_ORIG=$(sed -E 's/.*\(([a-z]+)\).*/\1/' <<< "$opts")
      [[ $opts == *voluntary* && $PREEMPT_ORIG != voluntary ]] ;;
    A) echo "$PREEMPT_ORIG" > $f ;;
    B) echo voluntary > $f ;;
  esac
}

k_kbdusb() {
  case $1 in
    init)
      KBD=""
      for d in /sys/bus/usb/devices/*; do
        [[ -r $d/idVendor ]] || continue
        local v p; read -r v < "$d/idVendor"; read -r p < "$d/idProduct"
        [[ $v:$p == 0414:8104 ]] && KBD=$d
      done
      [[ -n $KBD ]] && read -r KBD_ORIG < "$KBD/power/control" ;;
    A) echo "$KBD_ORIG" > "$KBD/power/control" ;;
    B) echo auto > "$KBD/power/control" ;;
  esac
}

declare -A IRQ_ORIG
k_irqpack() {
  case $1 in
    init)
      local i
      for i in /proc/irq/[0-9]*; do
        [[ -w $i/smp_affinity_list ]] && read -r IRQ_ORIG[$i] < "$i/smp_affinity_list"
      done
      read -r IRQ_DEF_ORIG < /proc/irq/default_smp_affinity
      read -r WQ_ORIG < /sys/devices/virtual/workqueue/cpumask
      # Yalnız TÜM CPU'lara açık (bağsız) kernel thread'ler; per-CPU olanlar
      # (ksoftirqd/N, kworker/N:M) tek CPU'ludur, dokunulmaz.
      KTHREADS=()
      local p cmd cpus
      for p in /proc/[0-9]*; do
        # cmdline'ı BOŞ olan kernel thread'dir. Dönüş koduna bakma: Chromium gibi
        # başlığını NUL'süz yeniden yazan süreçlerde read 1 döner ama içerik dolu.
        cmd=""; IFS= read -r -d "" cmd < "$p/cmdline" 2>/dev/null
        [[ -n $cmd ]] && continue
        cpus=$(awk '/^Cpus_allowed_list/{print $2}' "$p/status" 2>/dev/null)
        [[ $cpus == 0-15 ]] && KTHREADS+=("${p#/proc/}")
      done
      return 0 ;;
    A)
      local i
      for i in "${!IRQ_ORIG[@]}"; do echo "${IRQ_ORIG[$i]}" > "$i/smp_affinity_list" 2>/dev/null; done
      echo "$IRQ_DEF_ORIG" > /proc/irq/default_smp_affinity
      echo "$WQ_ORIG" > /sys/devices/virtual/workqueue/cpumask
      for p in "${KTHREADS[@]}"; do taskset -pc 0-15 "$p" >/dev/null 2>&1; done ;;
    B)
      local i
      for i in "${!IRQ_ORIG[@]}"; do echo "$ZEN5C" > "$i/smp_affinity_list" 2>/dev/null; done
      echo "$ZEN5C_HEX" > /proc/irq/default_smp_affinity
      echo "$ZEN5C_HEX" > /sys/devices/virtual/workqueue/cpumask
      for p in "${KTHREADS[@]}"; do taskset -pc "$ZEN5C" "$p" >/dev/null 2>&1; done ;;
  esac
}

k_dpm() {
  local f=/sys/class/drm/card1/device/power_dpm_force_performance_level
  case $1 in
    init) [[ -w $f ]] && read -r DPM_ORIG < $f && [[ $DPM_ORIG != low ]] ;;
    A) echo "$DPM_ORIG" > $f ;;
    B) echo low > $f ;;
  esac
}

hy() {
  local sig; sig=$(ls /run/user/"$UIDN"/hypr/ 2>/dev/null | head -1)
  runuser -u "$USERNAME" -- env XDG_RUNTIME_DIR=/run/user/"$UIDN" \
    HYPRLAND_INSTANCE_SIGNATURE="$sig" hyprctl "$@"
}
k_vrr() {
  case $1 in
    init) VRR_ORIG=$(hy getoption misc:vrr 2>/dev/null | awk '/^int:/{print $2}'); [[ -n $VRR_ORIG && $VRR_ORIG != 0 ]] ;;
    A) hy eval "hl.config({ misc = { vrr = $VRR_ORIG } })" >/dev/null ;;
    B) hy eval "hl.config({ misc = { vrr = 0 } })" >/dev/null ;;
  esac
}

k_vrr3() {
  case $1 in
    init) [[ ${PRE_VRR:-} == 0 ]] ;;
    A) hy eval "hl.config({ misc = { vrr = 0 } })" >/dev/null ;;
    B) hy eval "hl.config({ misc = { vrr = 3 } })" >/dev/null ;;
  esac
}

cg_of() {  # $1: pgrep -f deseni → ilk eşleşenin cgroup dizini
  local pid; pid=$(pgrep -f "$1" | head -1)
  [[ -n $pid ]] || return 1
  echo "/sys/fs/cgroup$(sed 's/^0:://' /proc/"$pid"/cgroup)"
}
k_cdfreeze() {
  case $1 in
    init) CD_CG=$(cg_of 'claude-desktop --ozone') && [[ -w $CD_CG/cgroup.freeze ]] ;;
    A) echo 0 > "$CD_CG/cgroup.freeze" ;;
    B) echo 1 > "$CD_CG/cgroup.freeze" ;;
  esac
}
k_cvfreeze() {
  case $1 in
    init) CV_CG=$(cg_of 'claude-voice/chromium --app') && [[ -w $CV_CG/cgroup.freeze ]] ;;
    A) echo 0 > "$CV_CG/cgroup.freeze" ;;
    B) echo 1 > "$CV_CG/cgroup.freeze" ;;
  esac
}

k_dpms() {
  case $1 in
    init) [[ -n $(ls /run/user/"$UIDN"/hypr/ 2>/dev/null) ]] ;;
    A) hy dispatch 'hl.dsp.dpms({ action = "on" })' >/dev/null ;;
    B) hy dispatch 'hl.dsp.dpms({ action = "off" })' >/dev/null ;;
  esac
}

k_bright() {
  local f=/sys/class/backlight/amdgpu_bl1
  case $1 in
    init) read -r BRIGHT_ORIG < $f/brightness; read -r BRIGHT_MAX < $f/max_brightness ;;
    A) echo "$BRIGHT_ORIG" > $f/brightness ;;
    B) echo $(( BRIGHT_MAX / 100 )) > $f/brightness ;;
  esac
}

k_wifi() {
  case $1 in
    init) rfkill list wlan >/dev/null 2>&1 ;;
    A) rfkill unblock wlan ;;
    B) rfkill block wlan ;;
  esac
}

# Kullanıcı yöneticisinin altındaki süreçli (yaprak) cgroup'lar; HARİÇ: init.scope,
# Hyprland ve bu betiğin ata zincirinin bulunduğu cgroup'lar (yoksa ölçüm donar).
k_apps() {
  local d
  case $1 in
    init)
      local U=/sys/fs/cgroup/user.slice/user-$UIDN.slice/user@$UIDN.service
      [[ -d $U ]] || return 1
      local -A skip=() ; local p=$$ cg
      while (( p > 1 )); do
        cg=$(sed 's/^0:://' /proc/$p/cgroup 2>/dev/null); skip[/sys/fs/cgroup$cg]=1
        p=$(awk '{print $4}' /proc/$p/stat 2>/dev/null) || break
      done
      APPS=()
      while IFS= read -r d; do
        d=${d%/cgroup.procs}
        # -s KULLANMA: cgroupfs dosyaları boyutu hep 0 bildirir; içeriğe bak.
        local first=""; read -r first < "$d/cgroup.procs" 2>/dev/null; [[ -n $first ]] || continue
        [[ -n ${skip[$d]:-} || $d == */init.scope || $d == *wayland-wm@* ]] && continue
        APPS+=("$d")
      done < <(find "$U" -name cgroup.procs)
      (( ${#APPS[@]} > 0 )) ;;
    A) for d in "${APPS[@]}"; do echo 0 > "$d/cgroup.freeze" 2>/dev/null; done ;;
    B) for d in "${APPS[@]}"; do echo 1 > "$d/cgroup.freeze" 2>/dev/null; done ;;
  esac
}

k_floor() {
  case $1 in
    init) k_apps init && k_wifi init && k_dpms init ;;
    A) k_dpms A; k_wifi A; k_apps A ;;
    B) k_apps B; k_wifi B; k_dpms B ;;
  esac
}

# ---- ölçüm --------------------------------------------------------------------
measure() {  # → MEAN_MW, MIN_MW, MAX_MW ; fork yok
  local i c v w sum=0 n=0 mn=999999999 mx=0
  for ((i = 0; i < M; i++)); do
    read -r c < $BAT/current_now; read -r v < $BAT/voltage_now
    w=$(( c * v / 1000000000 ))          # mW
    sum=$(( sum + w )); n=$(( n + 1 ))
    (( w < mn )) && mn=$w; (( w > mx )) && mx=$w
    nap 1
  done
  MEAN_MW=$(( sum / n )); MIN_MW=$mn; MAX_MW=$mx
}

ACTIVE=()
restore_all() {
  local k; for k in "${ACTIVE[@]}"; do "k_$k" A 2>/dev/null; done
  [[ -n ${PRE_VRR_ORIG:-} ]] && hy eval "hl.config({ misc = { vrr = $PRE_VRR_ORIG } })" >/dev/null
}
trap restore_all EXIT
trap 'exit 1' INT TERM HUP

if [[ -n ${PRE_VRR:-} ]]; then
  PRE_VRR_ORIG=$(hy getoption misc:vrr 2>/dev/null | awk '/^int:/{print $2}')
  hy eval "hl.config({ misc = { vrr = $PRE_VRR } })" >/dev/null
fi

for k in $KNOBS; do
  if "k_$k" init 2>/dev/null; then ACTIVE+=("$k"); else echo "atlandı: $k (init başarısız)" >&2; fi
done

{
  echo "power-ab $(date '+%F %T')  kollar: ${ACTIVE[*]}  M=$M S=$S sıra: $ORDER  PRE_VRR=${PRE_VRR:-yok}"
  read -r b < /sys/class/backlight/amdgpu_bl1/brightness; echo "parlaklık: $b  pil: $(cat $BAT/capacity)%"
} > "$OUT"

nap "$LEAD"

declare -A SUM CNT LIST
for k in "${ACTIVE[@]}"; do
  for arm in $ORDER; do
    read -r ac < /sys/class/power_supply/ACAD/online
    [[ $ac == 0 ]] || { echo "DURDU: fiş takıldı" >> "$OUT"; exit 1; }
    "k_$k" "$arm" 2>/dev/null
    nap "$S"
    measure
    psr="?"; [[ -r $PSR ]] && read -r psr < $PSR    # pencere BİTTİKTEN sonra
    read -r dg < $DGPU
    echo "$k $arm ort=${MEAN_MW} min=${MIN_MW} maks=${MAX_MW} psr=$psr dgpu=$dg" >> "$OUT"
    SUM[$k$arm]=$(( ${SUM[$k$arm]:-0} + MEAN_MW )); CNT[$k$arm]=$(( ${CNT[$k$arm]:-0} + 1 ))
    LIST[$k$arm]="${LIST[$k$arm]:-} $MEAN_MW"
  done
  "k_$k" A 2>/dev/null
  nap "$S"
done

{
  echo "--- özet (mW; Δ = B − A, negatif = tasarruf)"
  for k in "${ACTIVE[@]}"; do
    a=$(( SUM[${k}A] / CNT[${k}A] )); b=$(( SUM[${k}B] / CNT[${k}B] ))
    printf '%-9s A=%5d  B=%5d  Δ=%+5d   (A:%s | B:%s)\n' "$k" "$a" "$b" $(( b - a )) "${LIST[${k}A]}" "${LIST[${k}B]}"
  done
} >> "$OUT"
cat "$OUT"
