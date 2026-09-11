#!/usr/bin/env bash
# diag-game.sh — "oyun neden yavaş?" sorusunu OYUN AÇIKKEN tek seferde ölçer.
# Kullanım: oyun çalışırken ikinci bir terminalde →  bash scripts/diag-game.sh
#
# Bu makinede performans kaybının bilinen dört ana kolu var; betik dördünü de
# ayrı ayrı gösterir, böylece hangisinin ısırdığı tahmin değil ölçüm olur:
#   1) CPU maskesi   — cores.nix masaüstünü Zen5c'ye (3.5GHz) kilitler; oyunun
#                      bunu delmesi gerekir (gamerun → taskset -c 0-15)
#   2) game-perf     — 0xED profil 2 (ACBT 80→160) + turbo fan. Yoksa dGPU aç kalır
#   3) güç kaynağı   — pilde PPD power-saver + 2GHz tavan + ACBT 0 (tasarım gereği)
#   4) hangi GPU     — oyun gerçekten dGPU'da mı, iGPU'ya mı düştü
set -u

say() { printf '\n\033[1m== %s\033[0m\n' "$*"; }
val() { printf '  %-34s %s\n' "$1" "${2:-<okunamadı>}"; }
rd()  { cat "$1" 2>/dev/null; }

say "1) GÜÇ KAYNAĞI  (pildeyse her şey tasarım gereği kısıtlı)"
AC=$(rd /sys/class/power_supply/ACAD/online)
val "ACAD/online" "${AC:-?}  $([ "${AC:-0}" = 1 ] && echo '(fişte — DOĞRU)' || echo '(PİLDE — oyun için fişe tak!)')"
val "power profile" "$(powerprofilesctl get 2>/dev/null)"
# scaling_max TEK BAŞINA anlamsız — donanım tavanıyla (cpuinfo_max) kıyaslanmalı.
# İlk sürümde yalnız scaling_max basılıyordu ve "4.2 GHz düşük mü?" sorusu
# cevapsız kalıyordu (2 Eyl 2026, canlı ölçümde ortaya çıktı).
for P in 0 1; do
  CI=$(rd "/sys/devices/system/cpu/cpufreq/policy$P/cpuinfo_max_freq")
  SC=$(rd "/sys/devices/system/cpu/cpufreq/policy$P/scaling_max_freq")
  if [ -n "$CI" ] && [ "$CI" != "$SC" ]; then M="!! KISILMIŞ (tavan $CI)"; else M="tavanda"; fi
  val "policy$P scaling/cpuinfo max" "${SC:-?} / ${CI:-?} kHz   $M"
done
val "cpufreq/boost" "$(rd /sys/devices/system/cpu/cpufreq/boost)  (1 = açık)"
val "GR_CPUMAX bayrağı" "$([ -f "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/gamerun-cpumax" ] && echo 'VAR → PPD performance bekleniyor' || echo 'yok → PPD balanced bekleniyor')"

say "2) PERF ZİNCİRİ  (gamerun bunu sürer — yoksa dGPU bütçesi düşük kalır)"
val "game-perf.service" "$(systemctl is-active game-perf.service 2>&1)"
val "scx.service" "$(systemctl is-active scx.service 2>&1)"
val "sched_ext durumu" "$(rd /sys/kernel/sched_ext/state)  $(rd /sys/kernel/sched_ext/root/ops)"
val "fan_mode" "$(rd $(echo /sys/bus/wmi/devices/ABBC0F75-*/fan_mode))  (turbo, oyunda beklenen)"

say "3) CPU MASKESİ  (cores.nix Zen5c'ye kilitler; oyun 0-15 görmeli)"
FOUND=0
for P in $(pgrep -f 'Tsushima|GhostOfTsushima|\.exe' 2>/dev/null | head -8); do
  CMD=$(tr '\0' ' ' < "/proc/$P/comm" 2>/dev/null)
  CPUS=$(grep -m1 Cpus_allowed_list "/proc/$P/status" 2>/dev/null | awk '{print $2}')
  [ -z "$CPUS" ] && continue
  FOUND=1
  if [ "$CPUS" = "0-15" ]; then MARK="DOĞRU (maske delinmiş)"; else MARK="!! DAR — Zen5c'de kilitli, gamerun koşmamış"; fi
  val "pid $P ($CMD)" "$CPUS   $MARK"
done
[ "$FOUND" = 0 ] && val "oyun süreci" "bulunamadı (oyun kapalı mı?)"

say "4) HANGİ GPU + GÜÇ  (dGPU'da olmalı, yükte 70W+)"
if command -v nvidia-smi >/dev/null 2>&1; then
  # TEK örnek yanıltıcı: power.draw anlık dalgalanır. 5 saniyelik seri al.
  # (İlk sürüm tek örnek basıyordu → "54.75W düşük mü?" sorusu cevapsız kaldı.)
  echo "  --- 5 saniyelik seri (watt / SM MHz / util) — 0xED profil 2'de 62-83W beklenir ---"
  nvidia-smi --query-gpu=power.draw,clocks.sm,utilization.gpu,temperature.gpu \
             --format=csv,noheader -l 1 -c 5 2>/dev/null | sed 's/^/    /'
  nvidia-smi --query-gpu=name,power.limit,memory.used --format=csv,noheader 2>/dev/null | sed 's/^/  /'
  echo "  --- dGPU'da koşan süreçler (BOŞSA OYUN iGPU'DA!) ---"
  nvidia-smi --query-compute-apps=pid,process_name,used_memory --format=csv,noheader 2>/dev/null | sed 's/^/  /'
  nvidia-smi 2>/dev/null | sed -n '/Processes/,$p' | tail -n +3 | sed 's/^/  /'
fi

say "5) PANEL / VSYNC  (50-60 FPS bazen sadece 60Hz tavanıdır)"
# İlk sürüm burada HİÇBİR ŞEY basmadı (2 Eyl 2026): grep deseni tutmadı ve/veya
# hyprctl bu bağlamda yoktu. Artık ham çıktı + sysfs yedeği, sessiz kalmıyor.
if command -v hyprctl >/dev/null 2>&1 && hyprctl monitors >/dev/null 2>&1; then
  hyprctl monitors 2>&1 | sed 's/^/  /' | head -20
else
  val "hyprctl" "erişilemedi (HYPRLAND_INSTANCE_SIGNATURE yok? farklı oturum?)"
fi
for M in /sys/class/drm/card*-eDP-*/modes; do
  [ -f "$M" ] && val "$(dirname "$M" | xargs basename) ilk mod" "$(head -1 "$M")"
done

say "6) gamerun GERÇEKTEN KOŞTU MU  (asıl kanıt: Steam konsol logu)"
L=~/.local/share/Steam/logs/console-linux.txt
if [ -f "$L" ]; then
  N=$(grep -ac "gamerun: başlıyor" "$L" 2>/dev/null || echo 0)
  val "'gamerun: başlıyor' satırı" "$N adet  $([ "$N" -gt 0 ] && echo '(YENİ gamerun aktif)' || echo '(YOK → yeni gamerun Steam ortamında DEĞİL)')"
  grep -a "gamerun:" "$L" 2>/dev/null | tail -4 | sed 's/^/    /'
  val "'command not found'" "$(grep -ac 'gamerun: command not found' "$L" 2>/dev/null || echo 0) adet (0 olmalı)"
  val "gamemodeauto dlopen hatası" "$(grep -ac 'gamemodeauto: dlopen failed' "$L" 2>/dev/null || echo 0) adet (yeni gamerun'da 0 olmalı)"
fi

say "7) AKTİF SİSTEM  (switch yapıldı mı)"
val "/run/current-system" "$(readlink -f /run/current-system)"
val "kabuktaki gamerun" "$(readlink -f "$(command -v gamerun 2>/dev/null)" 2>/dev/null)"
G=$(readlink -f "$(command -v gamerun 2>/dev/null)" 2>/dev/null)
[ -n "$G" ] && val "  içinde VKREFLEX" "$(grep -c VKREFLEX "$G" 2>/dev/null) kez  (YENİde 0, ESKİde 1)"

printf '\n\033[1mBitti. Çıktının tamamını yapıştır.\033[0m\n'
