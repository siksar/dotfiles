# gamerun — Steam / Prism (mc-run) / emu-run ortak oyun sarmalayıcısı.
# - Yan etkiler (taskset, game-perf, PRIME) başarısız olursa uyar ve devam et; oyun hep açılır.
# - Vulkan katmanı / LD_PRELOAD enjekte etme (DXVK_NVAPI_VKREFLEX donduruyordu; gamemoderun'ın
#   LD_PRELOAD'ı pressure-vessel'i geçemiyor → game-perf.service doğrudan sürülür).
# - PRIME GL için __GLX_VENDOR_LIBRARY_NAME şart.
# - Fan turbo'su trap + referans sayacıyla kapanır; sızanı game-perf-reap.service toplar.
# Tüketiciler: usr/steam.nix + home/apps/games.nix — ikisini de build et.
{ pkgs }:

pkgs.writeShellScriptBin "gamerun" ''
  # %command% ZORUNLU: yoksa Steam bunu sarmalayıcı saymaz, oyunun argümanı olur.

  set -u

  GR_CO=${pkgs.coreutils}/bin          # mkdir/rm/id — FHS kum havuzunda PATH'e güvenme
  GR_TASKSET=${pkgs.util-linux}/bin/taskset
  GR_SYSTEMCTL=/run/current-system/sw/bin/systemctl   # /nix/store değil: KOŞAN sistemin
                                                      # systemd'siyle konuşmalı (sched.nix
                                                      # aynı gerekçeyle aynı yolu kullanır)

  gr_say() { [ "''${GR_QUIET:-0}" = "1" ] || echo "gamerun: $*" >&2; }

  # ---- %command% unutulmuş mu? ----
  if [ "$#" -eq 0 ]; then
    echo "gamerun: argüman yok. Steam launch options'ta '%command%' EKSİK." >&2
    echo "gamerun: doğrusu → gamerun %command%" >&2
    exit 2
  fi

  # ---- 1) PRIME offload (GL/EGL) — nvidia-offload ile aynı üçlü; Vulkan'a dokunmaz ----
  # Ters yön: __GLX_VENDOR_LIBRARY_NAME=mesa (LIBGL_ALWAYS_SOFTWARE=1 tek başına no-op).
  export __NV_PRIME_RENDER_OFFLOAD="''${__NV_PRIME_RENDER_OFFLOAD:-1}"
  export __NV_PRIME_RENDER_OFFLOAD_PROVIDER="''${__NV_PRIME_RENDER_OFFLOAD_PROVIDER:-NVIDIA-G0}"
  export __GLX_VENDOR_LIBRARY_NAME="''${__GLX_VENDOR_LIBRARY_NAME:-nvidia}"

  # ---- 2) Vulkan cihaz seçimi: varsayılan karışma (optimus katmanı listeyi filtreler) ----
  #   GR_GPU=nvidia → yalnız dGPU   GR_GPU=igpu → yalnız iGPU
  case "''${GR_GPU:-auto}" in
    auto) ;;
    nvidia) export __VK_LAYER_NV_optimus=NVIDIA_only ;;
    igpu)   export __VK_LAYER_NV_optimus=non_NVIDIA_only ;;
    *) gr_say "UYARI: GR_GPU=''${GR_GPU} tanınmadı (auto|nvidia|igpu) — yok sayıldı" ;;
  esac

  # ---- 3) CPU maskesi delme (cores.nix maskesi yumuşak; varsayılan 16 CPU) ----
  #   GR_PIN=big → Zen5 + SMT (0,2,..,14)   GR_PIN=fast → 4,6,12,14   GR_PIN=0,2,4 → ham liste
  case "''${GR_PIN:-}" in
    ""|all) GR_CPUS="0-15" ;;
    big)    GR_CPUS="0,2,4,6,8,10,12,14" ;;
    fast)   GR_CPUS="4,6,12,14" ;;
    *)      GR_CPUS="$GR_PIN" ;;
  esac
  # İlke A: maskeyi ÖNCE kuru kuruya dene. Geçersizse oyunu düşürme, uyar geç.
  if [ -x "$GR_TASKSET" ] && "$GR_TASKSET" -c "$GR_CPUS" true 2>/dev/null; then
    set -- "$GR_TASKSET" -c "$GR_CPUS" "$@"
  else
    gr_say "UYARI: taskset -c $GR_CPUS başarısız — CPU maskesi delinmedi (Zen5c'de kalır)"
    GR_CPUS="(uygulanmadı)"
  fi

  # ---- 4) Çalışma-zamanı durumu -------------------------------------------
  GR_RUNTIME="''${XDG_RUNTIME_DIR:-/run/user/$("$GR_CO/id" -u)}"
  GR_STATE="$GR_RUNTIME/gamerun.d"

  # GR_CPUMAX işareti game-perf'ten ÖNCE yazılmalı (game-perf okur: varsa performance, yoksa balanced).
  if [ "''${GR_CPUMAX:-0}" = "1" ]; then
    : > "$GR_RUNTIME/gamerun-cpumax" 2>/dev/null || true
  else
    "$GR_CO/rm" -f "$GR_RUNTIME/gamerun-cpumax" 2>/dev/null || true
  fi

  # ---- 5) game-perf.service — doğrudan, PID dosyalı referans sayacı ----
  GR_PERF=0
  if [ "''${GR_NOPERF:-0}" = "1" ]; then
    gr_say "game-perf ATLANDI (GR_NOPERF=1) — arıza ikilemesi için"
  elif [ ! -x "$GR_SYSTEMCTL" ]; then
    gr_say "UYARI: $GR_SYSTEMCTL yok — perf zinciri atlandı"
  else
    "$GR_CO/mkdir" -p "$GR_STATE" 2>/dev/null || true

    # Sızıntı sıfırlaması: SIGKILL'lenmiş örnek game-perf'i active bırakmışsa (oneshot + RemainAfterExit →
    # start ExecStart'ı yeniden koşturmaz) ölü kayıtları temizle, gerekirse yeniden başlat.
    GR_LIVE=0
    for GR_F in "$GR_STATE"/*; do
      [ -e "$GR_F" ] || continue
      GR_P="''${GR_F##*/}"
      if kill -0 "$GR_P" 2>/dev/null; then
        GR_LIVE=1
      else
        "$GR_CO/rm" -f "$GR_F" 2>/dev/null || true
      fi
    done
    # Sızmış/failed oturumda `restart`: stop + start yarışıyor (scx PartOf ~2 sn sürüyor, start iptal oluyor).
    GR_START_VERB=start
    GR_UNIT_ST=$("$GR_SYSTEMCTL" is-active game-perf.service 2>/dev/null || true)
    if [ "$GR_LIVE" = "0" ]; then
      case "$GR_UNIT_ST" in
        active)
          gr_say "önceki oturum sızmış (game-perf açık, canlı gamerun yok) — sıfırlanıyor"
          GR_START_VERB=restart
          ;;
        failed)
          gr_say "game-perf 'failed' kalmış — sıfırlanıyor"
          GR_START_VERB=restart
          ;;
      esac
    fi

    : > "$GR_STATE/$$" 2>/dev/null || true
    GR_PERF=1
    # --no-block: servis oyunun açılışını geciktirmesin.
    if "$GR_SYSTEMCTL" "$GR_START_VERB" --no-block game-perf.service 2>/dev/null; then
      gr_say "game-perf.service istendi (scx_lavd + AC'de 0xED profil 2 + turbo fan)"
    else
      gr_say "UYARI: game-perf.service başlatılamadı (polkit kuralı? sched.nix'e bak)"
    fi
  fi

  gr_cleanup() {
    trap - EXIT
    [ "$GR_PERF" = "1" ] || return 0
    "$GR_CO/rm" -f "$GR_STATE/$$" 2>/dev/null || true
    for GR_F in "$GR_STATE"/*; do
      [ -e "$GR_F" ] || continue
      GR_OTHER="''${GR_F##*/}"
      if kill -0 "$GR_OTHER" 2>/dev/null; then
        gr_say "başka gamerun örneği ($GR_OTHER) sürüyor — game-perf açık bırakıldı"
        return 0
      fi
      "$GR_CO/rm" -f "$GR_F" 2>/dev/null || true   # ölü kayıt
    done
    "$GR_CO/rm" -f "$GR_RUNTIME/gamerun-cpumax" 2>/dev/null || true
    "$GR_SYSTEMCTL" stop --no-block game-perf.service 2>/dev/null || true
    gr_say "game-perf.service durduruldu (fan/profil boot varsayılanına döner)"
  }

  # ---- 6) Oyunu çalıştır: exec değil, arka plan + wait (temizlik trap'i koşabilsin) ----
  gr_child=0
  gr_forward() { [ "$gr_child" -ne 0 ] && kill -TERM "$gr_child" 2>/dev/null; return 0; }
  trap gr_forward INT TERM HUP     # Steam'in "Durdur" düğmesi oyuna ulaşsın
  trap gr_cleanup EXIT

  gr_say "başlıyor — CPU=$GR_CPUS GPU=''${GR_GPU:-auto} perf=$GR_PERF"

  "$@" &
  gr_child=$!

  # Sinyal trap'i `wait`i >128 ile böler ama çocuk hâlâ yaşıyor olabilir →
  # gerçekten ölene kadar bekle, yoksa oyun ayaktayken fanı düşürürüz.
  gr_rc=0
  while :; do
    wait "$gr_child" && gr_rc=0 || gr_rc=$?
    kill -0 "$gr_child" 2>/dev/null || break
  done

  exit "$gr_rc"
''
