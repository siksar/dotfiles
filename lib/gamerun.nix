# gamerun — Steam/Prism/emu-run ortak oyun sarmalayıcısı. Taşındı (10 Ağu 2026):
# eskiden home/apps/games.nix'te tanımlıydı, ama usr/steam.nix (NixOS modülü)
# ile home/apps/games.nix (HM modülü) birbirini import edemiyor (CLAUDE.md,
# "Renaming rule" — system/usr/ ile home/ ayrı eval bağlamı). lib/theme.nix ile
# aynı desen: düz fonksiyon, iki taraf da import eder — system/ tarafı
# (usr/steam.nix) programs.steam.extraPackages ile Steam'in FHS kum havuzuna,
# home/ tarafı (home/apps/games.nix) home.packages ile normal PATH'e koyar.
#
# Taşımanın sebebi (Documentation/gaming.md, Faz "gamerun hiç çalışmıyordu"):
# Steam launch options'ı KENDİ FHS/pressure-vessel kabının İÇİNDE /bin/sh -c
# ile koşuyor; o kabın PATH'i yalnız /usr/bin:/bin — Home Manager profili
# (/etc/profiles/per-user/zixar/bin) o kapsülün dışında, "command not found"
# (10 Ağu 2026'ya kadar Steam konsol logunda tekrarlı). Bu dosya paket olarak
# FHS'e girdiği için kum havuzunda /usr/bin/gamerun oluşur, launch options
# `gamerun %command%` OLDUĞU GİBİ çalışır.
#
# Üç çağıranı var — env sözleşmesi hepsini etkiler:
#   Steam        launch options `gamerun %command%`
#   mc-run       home/apps/minecraft.nix → Prism WrapperCommand
#   emu-run      home/apps/emu.nix → rpcs3|shadps4
{ pkgs }:

pkgs.writeShellScriptBin "gamerun" ''
  # gamerun — dGPU offload + Reflex + ntsync + gamemode + CPU maske açma (cores.nix'i deler)
  # Kullanım (Steam launch options): gamerun %command%
  # Oyun başına ezme: "VAR=değer gamerun %command%" (tüm varsayılanlar :- ile)
  #
  # --- 10 Ağu 2026: bu sarmalayıcı Steam'den HİÇ çalışmıyordu (FHS kum
  # havuzunda yoktu — yukarıdaki dosya başlığına bak). İlk kez gerçekten
  # koşacağı için hiçbir blok bu makinede test edilmedi; riskli bloklar
  # varsayılan-açıktan opt-in'e taşındı. Teker teker aç: ---
  #   GR_NVONLY=1   → AMD Vulkan/GL cihazını gizle (__VK_LAYER_NV_optimus=
  #                   NVIDIA_only, __GLX_VENDOR_LIBRARY_NAME=nvidia). RİSKLİ:
  #                   NVIDIA ICD kum havuzunda görünmezse oyun SIFIR Vulkan
  #                   cihazı görür → anında kapanır.
  #   GR_DLSS=1     → NGX updater + DLSS SR/RR sürücü override'ı. OptiScaler
  #                   kullanan oyunlarla (PROTON_USE_OPTISCALER=1) AYNI
  #                   katmanda çakışır — o oyunlarda AÇMA.
  #   GR_CACHE=1    → NVIDIA GL disk shader cache (~/.cache/nv, 12GB tavan,
  #                   kalıcı — temizlik kapalı).
  #
  # Opt-in anahtarlar:
  #   GR_MFG=2..6   → DLSS Multi Frame Generation (2x..6x; FG override'ı da açar)
  #   GR_DYNFG=165  → Dinamik MFG: hedef FPS'e otomatik çarpan (GR_MFG'yi ezer)
  #   GR_FG=1       → DLSS Frame Generation override'ı aç (GR_MFG/GR_DYNFG zaten açar)
  #   GR_PRESET=latest → DLSS render preset'i zorla (varsayılan: sürücü/oyun preset'i)
  #   GR_NTSYNC=1   → Proton ntsync'i zorla aç (GR_NTSYNC=0 ile kapat)
  #   GR_SMOOTH=1   → sürücü Smooth Motion (DLSS'siz oyunlara framegen; FG/MFG ile BİRLEŞMEZ)
  #   GR_LL=1       → düşük gecikme kare tempolama (D3D11+D3D12). YALNIZ Proton-CachyOS.
  #                   Reflex'i çeviri katmanında uygular + VRR-farkında pacing (165Hz).
  #                   FG/MFG ile BİRLEŞMEZ; Reflex/Waitable-Swapchain'siz oyunda no-op.
  #   GR_WL=1       → Proton Wayland (deneysel; Steam Overlay/Input bozulur)
  #   GR_PIN=big    → yalnız Zen5 "big" çekirdekler (HOI4 gibi tek-çekirdek oyunlar)
  #   GR_PIN=fast   → yalnız en hızlı 2 çekirdek: cpu4/6 + SMT 12/14. İki bağımsız
  #                   firmware sıralaması da bu dörtlüyü işaret ediyor (CPPC
  #                   prefcore_ranking 208, ITMT sched_core_priority 203).
  #   GR_PIN=0,2,4  → özel CPU listesi (taskset -c biçimi)
  #   GR_WIN=WxH    → windowed aç, verilen boyutta (varsayılan: TAM EKRAN, argümansız)
  #   GR_CPUMAX=1   → CPU-ağır oyunda tam güç (PPD performance). Varsayılan balanced:
  #                   GPU-öncelik — dGPU'ya paylaşımlı Dynamic Boost bütçesi bırakır.
  #
  #   --- Blackwell DX12/VKD3D kararlılık kaçış-flag'leri (opt-in; Documentation/gaming.md) ---
  #   GR_VKD3DNOCACHE=1 → VKD3D shader cache'i kapat (VKD3D_SHADER_CACHE_PATH=0). NVIDIA'da
  #                   DX12 oyunları bir süre oynayınca donarsa/çökerse (vkd3d-proton #2793).
  #                   Bedel: ilk-render shader stutter'ı artar → YALNIZ donan oyunda aç.
  #   GR_HEAP=1     → PROTON_VKD3D_HEAP=1: VK_EXT_descriptor_heap ile Blackwell Xid 109 sert
  #                   çökme düzeltmesi (vkd3d-proton #2914). YALNIZ bunu içeren Proton'da
  #                   etkin → Steam'de o oyuna Proton-CachyOS seç; GE-Proton'da zararsız no-op.
  #   GR_VKD3D=...   → ham VKD3D_CONFIG passthrough (ileri per-oyun: dxr11, force_raw_va_cbv…)

  # --- dGPU PRIME offload (RTX 5060) ---
  export __NV_PRIME_RENDER_OFFLOAD="''${__NV_PRIME_RENDER_OFFLOAD:-1}"
  export __NV_PRIME_RENDER_OFFLOAD_PROVIDER="''${__NV_PRIME_RENDER_OFFLOAD_PROVIDER:-NVIDIA-G0}"

  # GR_NVONLY — opt-in: AMD Vulkan/GL cihazını gizleyip NVIDIA'yı zorunlu kılar.
  # Varsayılan KAPALI (10 Ağu 2026): NVIDIA ICD pressure-vessel kum havuzunda
  # görünmezse oyun sıfır Vulkan cihazı görür → anında kapanır — bu sarmalayıcı
  # hiç test edilmediği için riski üstlenmiyoruz. PRIME offload yukarıda zaten
  # dGPU'yu seçtiriyor; bu yalnız AMD'yi tamamen görünmez yapar.
  if [ "''${GR_NVONLY:-0}" = "1" ]; then
    export __VK_LAYER_NV_optimus="''${__VK_LAYER_NV_optimus:-NVIDIA_only}"
    export __GLX_VENDOR_LIBRARY_NAME="''${__GLX_VENDOR_LIBRARY_NAME:-nvidia}"
  fi

  # --- DLSS 4.5: NGX updater (en yeni DLL) + SR/RR override — opt-in GR_DLSS=1 ---
  # Varsayılan KAPALI (10 Ağu 2026): kullanıcının OptiScaler kullanan oyunlarıyla
  # (PROTON_USE_OPTISCALER=1 PROTON_DLSS_UPGRADE=1) aynı katmanda çakışıyor —
  # OptiScaler zaten kendi NGX/nvapi override'ını yapıyor, ikisi aynı DLL'e oynar.
  if [ "''${GR_DLSS:-0}" = "1" ]; then
    export PROTON_ENABLE_NGX_UPDATER="''${PROTON_ENABLE_NGX_UPDATER:-1}"
    export DXVK_NVAPI_DRS_NGX_DLSS_SR_OVERRIDE="''${DXVK_NVAPI_DRS_NGX_DLSS_SR_OVERRIDE:-on}"
    export DXVK_NVAPI_DRS_NGX_DLSS_RR_OVERRIDE="''${DXVK_NVAPI_DRS_NGX_DLSS_RR_OVERRIDE:-on}"
  fi

  # FG override — opt-in: GR_FG=1, ya da FG'yi zaten kullanan GR_MFG/GR_DYNFG.
  if [ "''${GR_FG:-0}" = "1" ] || [ -n "''${GR_MFG:-}''${GR_DYNFG:-}" ]; then
    export DXVK_NVAPI_DRS_NGX_DLSS_FG_OVERRIDE="''${DXVK_NVAPI_DRS_NGX_DLSS_FG_OVERRIDE:-on}"
  fi

  # DLSS render preset — opt-in: GR_PRESET=latest (ya da a..k / j gibi harf).
  if [ -n "''${GR_PRESET:-}" ]; then
    export DXVK_NVAPI_DRS_NGX_DLSS_SR_OVERRIDE_RENDER_PRESET_SELECTION="render_preset_''${GR_PRESET}"
    export DXVK_NVAPI_DRS_NGX_DLSS_RR_OVERRIDE_RENDER_PRESET_SELECTION="render_preset_''${GR_PRESET}"
  fi

  # --- Gecikme + CPU senkron ---
  export DXVK_NVAPI_VKREFLEX="''${DXVK_NVAPI_VKREFLEX:-1}"  # Reflex — güvenli, açık kalır
  # ntsync opt-in (2026-07-17): eskiden PROTON_USE_NTSYNC=1 zorlanıyordu, bu
  # GE-Proton'un per-game ntsync blocklist'ini eziyordu → bazı oyunlarda çökme/
  # hang. Artık Proton kendi karar verir; GR_NTSYNC=1 zorla aç / =0 kesin kapat.
  [ -n "''${GR_NTSYNC:-}" ] && export PROTON_USE_NTSYNC="$GR_NTSYNC"

  # --- Shader cache (NVIDIA GL — kalıcı/büyük) — opt-in GR_CACHE=1 ---
  # DXVK state cache + VKD3D cache varsayılan açık ve per-oyun; onlara dokunulmaz
  # (VKD3D cache donma yaparsa GR_VKD3DNOCACHE ile kapatılır). Bu blok yalnız NVIDIA'nın
  # GL/NGX disk shader cache'ini büyük+kalıcı tutar. Varsayılan KAPALI (10 Ağu 2026):
  # test edilmedi + 12GB disk taahhüdü sessizce başlamamalı.
  if [ "''${GR_CACHE:-0}" = "1" ]; then
    export __GL_SHADER_DISK_CACHE="''${__GL_SHADER_DISK_CACHE:-1}"
    export __GL_SHADER_DISK_CACHE_PATH="''${__GL_SHADER_DISK_CACHE_PATH:-$HOME/.cache/nv}"
    export __GL_SHADER_DISK_CACHE_SIZE="''${__GL_SHADER_DISK_CACHE_SIZE:-12000000000}"  # ~12GB
    export __GL_SHADER_DISK_CACHE_SKIP_CLEANUP="''${__GL_SHADER_DISK_CACHE_SKIP_CLEANUP:-1}"
  fi

  # --- Frame Generation anahtarları ---
  if [ -n "''${GR_DYNFG:-}" ]; then
    # Dinamik MFG (DLSS 4.5): hedef FPS'e göre 2x..6x otomatik çarpan
    export DXVK_NVAPI_DRS_NGX_DLSSG_MODE=dynamic
    export DXVK_NVAPI_DRS_NGX_DLSSG_DYNAMIC_TARGET_FRAME_RATE="$GR_DYNFG"
    export DXVK_NVAPI_DRS_NGX_DLSSG_DYNAMIC_MULTI_FRAME_COUNT_MAX=5
  elif [ -n "''${GR_MFG:-}" ]; then
    case "$GR_MFG" in
      2|3|4|5|6)
        export DXVK_NVAPI_DRS_NGX_DLSSG_MODE=on
        export DXVK_NVAPI_DRS_NGX_DLSSG_MULTI_FRAME_COUNT=$((GR_MFG - 1))
        ;;
      *) echo "gamerun: GR_MFG 2-6 arası olmalı (verilen: $GR_MFG) — yok sayıldı" >&2 ;;
    esac
  fi

  if [ "''${GR_SMOOTH:-0}" = "1" ]; then
    if [ -n "''${GR_MFG:-}''${GR_DYNFG:-}" ]; then
      # Resmî kural: Smooth Motion + FG/MFG birlikte = artefakt + düşük perf
      echo "gamerun: UYARI — GR_SMOOTH, GR_MFG/GR_DYNFG ile birleşmez; Smooth Motion YOK SAYILDI" >&2
    else
      export NVPRESENT_ENABLE_SMOOTH_MOTION=1
    fi
  fi

  # --- Düşük gecikme kare tempolama (GR_LL) — YALNIZ Proton-CachyOS ---
  # netborg-afps/{dxvk,vkd3d}-low-latency, proton-cachyos 11.0-20260703'te geldi
  # (GE-Proton'da YOK — Steam'de o oyuna Proton-CachyOS seçilmeli, yoksa no-op).
  # Reflex'i çeviri katmanının İÇİNDE uygular (VK_NV_low_latency2'ye dönüştürmeden)
  # + Waitable DXGI Swapchain ile kare tempolar.
  #
  # low-latency-vrr-165: v-blank'i hesaba katıp v-sync tamponlama gecikmesini keser.
  # Bu makineye özel uyuyor — 165Hz panel + Hyprland vrr=2 (tam ekranda VRR açık) +
  # gamerun varsayılanı tam ekran. Farklı hedef için: DXVK_FRAME_PACE=... GR_LL=1 …
  #
  # SINIRLAR (üstakım README):
  #  • Frame Generation DESTEKLENMİYOR → GR_MFG/GR_DYNFG ile birleşmez (aşağıda guard).
  #  • Oyun ya Reflex marker'ı göndermeli ya Waitable Swapchain kullanmalı; yoksa NO-OP.
  #  • CPU-bound sahnede tavan FPS'i DÜŞÜREBİLİR (kareler CPU'da örtüşmüyor).
  #  • D3D12 tarafı "initial-release"; VRR pacing modu D3D12'de henüz yok.
  if [ "''${GR_LL:-0}" = "1" ]; then
    if [ -n "''${GR_MFG:-}''${GR_DYNFG:-}" ]; then
      echo "gamerun: UYARI — GR_LL, GR_MFG/GR_DYNFG ile birleşmez (vkd3d-low-latency FG desteklemiyor); low-latency YOK SAYILDI" >&2
    else
      export PROTON_DXVK_LOWLATENCY=1                                      # D3D11
      export PROTON_VKD3D_LOWLATENCY=1                                     # D3D12
      export DXVK_FRAME_PACE="''${DXVK_FRAME_PACE:-low-latency-vrr-165}"
    fi
  fi

  [ "''${GR_WL:-0}" = "1" ] && export PROTON_ENABLE_WAYLAND=1

  # --- Pencere modu: VARSAYILAN TAM EKRAN (2026-07-17) ---
  # Windowed varsayılanı eski Hyprland+waybar rice'ı içindi (bar'lı alana sığsın
  # diye); GNOME'da tam ekran zaten sorunsuz + daha az kompozisyon yükü. Bu yüzden
  # varsayılanda HİÇBİR pencere argümanı eklenmez → oyunlar kendi (genelde tam
  # ekran) davranışını kullanır. GR_WIN=WxH VERİLİRSE windowed'a geç:
  # -w/-h/-freq/-windowed (Source sözleşmesi) + -screen-* (Unity sözleşmesi:
  # House Flipper, Phasmophobia, Planet Crafter). Tanımayan motorlar yok sayar.
  # NOT: kendi config'i windowed'a ayarlı oyunlar (FromSoft/HOI4/KCD/RE/Hogwarts,
  # *.bak yedekleri var) yine pencereli açılır — onlar bu bayraklardan bağımsız.
  GR_WIN="''${GR_WIN:-0}"
  if [ "$GR_WIN" != "0" ]; then
    set -- "$@" -w "''${GR_WIN%x*}" -h "''${GR_WIN#*x}" -freq 165 -windowed \
      -screen-width "''${GR_WIN%x*}" -screen-height "''${GR_WIN#*x}" -screen-fullscreen 0
  fi

  # --- CPU güç profili işareti (GR_CPUMAX) ---
  # game-perf.service (root) oyunda PPD'yi VARSAYILAN balanced yapar (GPU-öncelik:
  # CPU+dGPU paylaşımlı Dynamic Boost bütçesini dGPU'ya bırakır). GR_CPUMAX=1 ise
  # burada bir işaret dosyası bırakırız; game-perf (ve power-display) onu okuyup
  # performance'a geçer — CPU-bound oyunlar için. gamemode başlamadan ÖNCE yazılmalı,
  # o yüzden exec'ten önce burada. Oyun bitince game-perf stop dosyayı siler.
  GR_RUNTIME="''${XDG_RUNTIME_DIR:-/run/user/$(${pkgs.coreutils}/bin/id -u)}"
  if [ "''${GR_CPUMAX:-0}" = "1" ]; then
    : > "$GR_RUNTIME/gamerun-cpumax" 2>/dev/null || true
  else
    rm -f "$GR_RUNTIME/gamerun-cpumax" 2>/dev/null || true
  fi

  # --- CPU pinleme / maske delme (heterojen Zen5/Zen5c — Ryzen AI 7 350) ---
  # system/kernel/cores.nix systemd manager'ı VARSAYILAN Zen5c'ye kilitler
  # (1,3,5,7,9,11,13,15 — masaüstü politikası, oyun dışı işler orada kalsın diye)
  # ve bu, fork/exec zinciriyle Steam üzerinden buraya da miras kalır. Oyun bu
  # mirası burada deler: GR_PIN verilmezse taskset -c 0-15 (tüm 16 CPU açılır).
  # big = 4× Zen5 5.09GHz (cpu 0,2,4,6 + SMT 8,10,12,14); Zen5c 3.5GHz dışarıda.
  # GR_PIN=big/fast İDDİASI ZAYIFLADI (16 Ağu 2026 düzeltmesi): zamanlayıcı
  # Zen5/Zen5c ayrımını BİLİYOR — ITMT açık, Zen5 önceliği 203'e karşı Zen5c 135
  # (Documentation/aerox16/cpu-hybrid.md). Yani 0-15 havuzunda tek-thread'lik iş
  # "şansa göre" değil, TERCİHEN Zen5'e gider; eski gerekçe (prefcore=disabled →
  # zamanlayıcı kör) yanlıştı. GR_PIN=big/fast yine de GARANTİ sunar: ITMT bir
  # tercihtir, yük altında zamanlayıcı yine de Zen5c'ye taşıyabilir. Tek-çekirdeğe
  # bağımlı sim oyunlarında (HOI4/Stellaris/Factorio) kullan, ama "olmazsa olmaz"
  # değil — önce GR_PIN'siz dene.
  if [ -n "''${GR_PIN:-}" ]; then
    case "$GR_PIN" in
      big)  GR_CPUS="0,2,4,6,8,10,12,14" ;;
      fast) GR_CPUS="4,6,12,14" ;;
      *)    GR_CPUS="$GR_PIN" ;;
    esac
  else
    GR_CPUS="0-15"   # cores.nix maskesini tamamen del — varsayılan
  fi
  GR_PREFIX="${pkgs.util-linux}/bin/taskset -c $GR_CPUS"

  # --- Blackwell DX12/VKD3D kararlılık kaçış-flag'leri (opt-in, VARSAYILAN KAPALI) ---
  # Neden opt-in ve neden varsayılan kapalı: kullanıcıda şu an donma YOK → bu koşulların
  # herkese stutter (NOCACHE) veya gereksiz yan-etki bindirmesini istemiyoruz. Belirli bir
  # DX12/Blackwell oyunu takılırsa cerrahi olarak o oyuna eklenir (Documentation/gaming.md).
  [ "''${GR_VKD3DNOCACHE:-0}" = "1" ] && export VKD3D_SHADER_CACHE_PATH=0   # #2793 NVIDIA DX12 donma escape
  [ "''${GR_HEAP:-0}" = "1" ] && export PROTON_VKD3D_HEAP=1                 # #2914 Blackwell Xid109 descriptor_heap
  [ -n "''${GR_VKD3D:-}" ] && export VKD3D_CONFIG="$GR_VKD3D"               # ileri per-oyun passthrough

  exec $GR_PREFIX ${pkgs.gamemode}/bin/gamemoderun "$@"
''
