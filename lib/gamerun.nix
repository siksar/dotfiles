# gamerun — Steam / Prism (mc-run) / emu-run ortak oyun sarmalayıcısı.
#
# SIFIRDAN YAZILDI 2 Eyl 2026. Eski sürümün neyi yanlış yapıyordu ve bu sürüm
# hangi ilkeyle kuruldu — ikisi de aşağıda, çünkü bu dosyanın tarihi bir kez
# daha aynı tuzağa düşmeye çok müsait.
#
# ---------------------------------------------------------------------------
# ÖLÇÜLEN ARIZA (2 Eyl 2026) — dört ayrı kök neden
# ---------------------------------------------------------------------------
# (1) OYUN AÇILMIYOR / AYAR MENÜSÜNDE DONUYOR  →  DXVK_NVAPI_VKREFLEX=1
#     Eski gamerun bunu KOŞULSUZ export ediyordu ve "Reflex, güvenli, açık
#     kalır" diye yorumlanmıştı. Değişken bir ayar değil, bir VULKAN KATMANI
#     ANAHTARI: proton-cachyos içindeki
#       share/dxvk-nvapi-vkreflex-layer/implicit_layer.d/VkLayer_DXVK_NVAPI_reflex.json
#     manifestinde  "enable_environment": { "DXVK_NVAPI_VKREFLEX": "1" }  yazıyor.
#     Katman VK_NV_low_latency (revizyon 1, ESKİ) uzantısını taklit eder.
#     Ama bu makinenin sürücüsü (NVIDIA 610.57.04) zaten YERLİSİNİ veriyor:
#       VK_NV_low_latency2 : extension revision 2   ← dxvk-nvapi'nin kullandığı
#       VK_NV_low_latency  : extension revision 1   ← katmanın taklit ettiği
#     Yani katman GEREKSİZ; tek yaptığı oyunla sürücü arasına fazladan bir
#     aracı koymak.
#     KANITIN SINIRI: (a) değişkenin katman anahtarı olduğu ve (b) sürücünün
#     low_latency2'yi yerlisinden verdiği ÖLÇÜLDÜ → (c) katman gereksiz.
#     Donmaların BU katmandan geldiği ÖLÇÜLMEDİ — çıkarım (ayar menüsü
#     swapchain'i yeniden kurar, bir katmanın en kırılgan anı odur). Kaldırma
#     kararı yine de (c) ile tek başına haklı. Donma sürerse sonraki şüpheli:
#     system/drivers/gpu.nix'teki powerManagement.finegrained (dGPU runtime
#     D3cold uyandırma) ve Proton sürümü. Ayrıntı: Documentation/gaming.md.
#     Bu, home/apps/games.nix'in MangoHud'u kaldırma gerekçesiyle AYNI SINIF
#     hata ("oyun↔Vulkan sürücüsü arasına giren katman"). O ilke burada
#     ihlal edilmişti; bu sürüm ilkeye geri dönüyor: gamerun HİÇBİR Vulkan
#     katmanı enjekte etmez.
#
# (2) PERF ZİNCİRİ HİÇ TETİKLENMİYORDU  →  gamemoderun'ın LD_PRELOAD'ı
#     Eski gamerun son adımda `exec gamemoderun "$@"` yapıyordu. gamemoderun
#     işini LD_PRELOAD=libgamemodeauto.so.0 + LD_LIBRARY_PATH=<nix store>
#     ile yapar. Oyun ise Steam'in pressure-vessel KONTEYNERİ içinde açılır;
#     o konteyner kendi LD_LIBRARY_PATH'ini kurar ve o store yolu içeride yok.
#     Ölçülen sonuç (~/steam-1245620.log, Elden Ring — her satırda tekrar):
#       gamemodeauto: dlopen failed - libgamemode.so: cannot open shared object file
#     → gamemode aktive OLMUYOR → custom.start kancası koşmuyor →
#       game-perf.service, scx_lavd, 0xED profili, turbo fan: HİÇBİRİ yok.
#     10 Ağu 2026'daki "gamerun artık çalışıyor" düzeltmesi yalnızca
#     `command not found`u çözmüş; zincirin geri kalanı 2 Eyl'e kadar ölüydü.
#     Üstelik bu LD_PRELOAD her oyun sürecine miras kalıyor — anti-cheat'li
#     oyunlarda (Elden Ring start_protected_game.exe = EAC) ek risk.
#
#     ÇÖZÜM: gamemode'u aradan çıkar, game-perf.service'i DOĞRUDAN sür.
#     Ölçüldü (2 Eyl 2026, kullanıcı zixar, parolasız):
#       systemctl start game-perf.service → rc=0
#       scx.service → active | fan_mode → 5 (turbo) | PPD → balanced
#     İzni system/kernel/sched.nix'teki polkit kuralı zaten veriyordu; eski
#     gamerun bu hazır ve çalışan yolu kullanmak yerine kırık LD_PRELOAD
#     zincirinden geçiyordu.
#
# (3) PRIME OFFLOAD OpenGL'DE HİÇ ÇALIŞMIYORDU  →  __GLX_VENDOR_LIBRARY_NAME
#     __NV_PRIME_RENDER_OFFLOAD=1 TEK BAŞINA GLX'i yönlendirmez; libglvnd'nin
#     hangi satıcıyı yükleyeceğini __GLX_VENDOR_LIBRARY_NAME belirler. Eski
#     gamerun onu GR_NVONLY'nin (varsayılan kapalı) arkasına saklamıştı.
#     glxinfo -B ile ölçüldü: ESKİ gamerun → AMD Radeon 860M, YENİ → RTX 5060.
#     Minecraft (mc-run → gamerun, LWJGL OpenGL) bugüne kadar iGPU'daymış.
#     Ayrıntılı tablo aşağıda, 1. bloğun yorumunda + Documentation/gaming.md.
#
# (4) scx.service İKİ OYUN AÇILIŞINDA ÖLÜYORDU (yan bulgu, sched.nix'te düzeltildi)
#     Upstream scx modülü StartLimitBurst=2 / StartLimitIntervalSec=30s koyuyor →
#     30 sn içinde iki launch = kalıcı `failed`, reset-failed'sız bir daha
#     başlamıyor. Yani çöken oyunu hemen tekrar açmak scx_lavd'ı öldürüyordu.
#     system/kernel/sched.nix'te startLimitIntervalSec = lib.mkForce 0.
#
# ---------------------------------------------------------------------------
# TASARIM İLKELERİ (bu dosyayı değiştirirken bunları bozma)
# ---------------------------------------------------------------------------
#  A. OYUN HER HÂLÜKÂRDA AÇILIR. Buradaki her yan etki (taskset, game-perf,
#     PRIME) opsiyoneldir ve BAŞARISIZ OLURSA uyarı basıp devam eder. Hiçbir
#     kod yolu oyunu başlatmamaya karar veremez. Arıza (1) tam da bunun
#     yokluğundan doğdu.
#  B. KATMAN ENJEKTE ETME. Vulkan katmanı / LD_PRELOAD yok. Sadece süreç
#     nitelikleri (env, CPU affinity) ve sistem servisleri.
#  C. YALNIZ ÖLÇÜLMÜŞ İŞ. DLSS/MFG/FG/SmoothMotion/low-latency/ntsync/VKD3D
#     env'leri BURADAN ÇIKARILDI (2 Eyl 2026). Hiçbiri bu makinede
#     ölçülmemişti, hepsi oyuna özgü ve hepsi launch options'a doğrudan
#     yazılabilir:  PROTON_USE_NTSYNC=1 gamerun %command%
#     gamerun onları ezmez (hiç dokunmaz) — bu yüzden pass-through anahtarına
#     da gerek yok. Tablo: Documentation/gaming.md.
#  D. TEMİZLİK GARANTİLİ. Fan turbo'da unutulursa dizüstü sonsuza kadar gürültü
#     yapar. trap + referans sayacı ile çıkışta mutlaka durur.
#     SIGKILL kaçağı 12 Eyl 2026'da KAPATILDI (trap hâlâ yakalanamıyor, ama artık
#     tek savunma trap değil): (1) bir sonraki gamerun başlarken sızmış oturumu
#     tespit edip sıfırlıyor — aşağıdaki 5. blok; (2) system/kernel/sched.nix'teki
#     `game-perf-reap.service` aynı denetimi udev (ACAD) ve uyanışta koşuyor.
#     Bu ikinci ağ şart, çünkü sızmış bir game-perf yalnız fanı turbo'da bırakmıyor:
#     aero-power-profile ve power-display `is-active game-perf` görünce fan/affinity
#     yazmayı atlıyor, yani sızıntı bütün kurtarma yollarını da kapatıyordu.
#
# ---------------------------------------------------------------------------
# NEDEN lib/ ALTINDA (10 Ağu 2026 taşıması — hâlâ geçerli)
# ---------------------------------------------------------------------------
# usr/steam.nix (NixOS modülü) ile home/apps/games.nix (HM modülü) birbirini
# import EDEMEZ — ayrı eval bağlamları (CLAUDE.md). lib/theme.nix ile aynı
# desen: düz fonksiyon, iki taraf da import eder.
#   • usr/steam.nix     → programs.steam.extraPackages → Steam'in FHS kum
#     havuzunda /usr/bin/gamerun oluşur. BUNSUZ launch options "command not
#     found" verir (kum havuzunun PATH'i yalnız /usr/bin:/bin).
#   • home/apps/games.nix → home.packages → normal kullanıcı PATH'i.
# Üç çağıranı var:
#   Steam    launch options `gamerun %command%`
#   mc-run   home/apps/minecraft.nix → Prism WrapperCommand
#   emu-run  home/apps/emu.nix → rpcs3|shadps4
{ pkgs }:

pkgs.writeShellScriptBin "gamerun" ''
  # gamerun — dGPU offload + CPU maskesi delme + game-perf zinciri.
  # Kullanım (Steam launch options):  gamerun %command%
  # %command% ZORUNLU — içermeyen dize Steam'de sarmalayıcı SAYILMAZ, sessizce
  # oyunun argümanı olur (localconfig.vdf'de "gamerun" yazan bir satır vardı).

  set -u

  GR_CO=${pkgs.coreutils}/bin          # mkdir/rm/id — FHS kum havuzunda PATH'e güvenme
  GR_TASKSET=${pkgs.util-linux}/bin/taskset
  GR_SYSTEMCTL=/run/current-system/sw/bin/systemctl   # /nix/store değil: KOŞAN sistemin
                                                      # systemd'siyle konuşmalı (sched.nix
                                                      # aynı gerekçeyle aynı yolu kullanır)

  gr_say() { [ "''${GR_QUIET:-0}" = "1" ] || echo "gamerun: $*" >&2; }

  # ---- İlk kontrol: %command% unutulmuş mu? -------------------------------
  # Sessiz kalmak yerine yüksek sesle söyle — eski hâlinde bu hata Steam'de
  # hiçbir iz bırakmadan oyunu argümansız çalıştırıyordu.
  if [ "$#" -eq 0 ]; then
    echo "gamerun: argüman yok. Steam launch options'ta '%command%' EKSİK." >&2
    echo "gamerun: doğrusu → gamerun %command%" >&2
    exit 2
  fi

  # ---- 1) dGPU PRIME offload (GL/EGL tarafı) ------------------------------
  # nixpkgs'in kendi `nvidia-offload` betiğiyle AYNI üçlü. Eski gamerun
  # __GLX_VENDOR_LIBRARY_NAME'i GR_NVONLY'nin arkasına saklıyordu → yarım
  # yapılandırma: "NVIDIA'ya offload et" deniyor ama GLX hâlâ mesa'ya
  # gidiyordu. ÖLÇÜLDÜ (glxinfo -B): ESKİ gamerun → "AMD Radeon 860M (radeonsi)",
  # YENİ gamerun → "NVIDIA GeForce RTX 5060". Yani PRIME offload OpenGL'de HİÇ
  # çalışmıyormuş; Minecraft bugüne kadar iGPU'da koşmuş. Vulkan oyunları
  # etkilenmedi (DXVK cihazı kendi seçer) — arıza bu yüzden görünmedi.
  # Ters yön gerekirse dışarıdan ezilir (:- deseni): LIBGL_ALWAYS_SOFTWARE=1 TEK
  # BAŞINA no-op olur (Mesa değişkeni, nvidia satıcısını ilgilendirmez) →
  # __GLX_VENDOR_LIBRARY_NAME=mesa ile birlikte yaz. HOI4 launcher düzeltmesi budur.
  # Bu üçü YALNIZ GL/EGL'i etkiler, Vulkan cihaz sayımına DOKUNMAZ → oyunun
  # sıfır cihaz görüp kapanma riski yok.
  export __NV_PRIME_RENDER_OFFLOAD="''${__NV_PRIME_RENDER_OFFLOAD:-1}"
  export __NV_PRIME_RENDER_OFFLOAD_PROVIDER="''${__NV_PRIME_RENDER_OFFLOAD_PROVIDER:-NVIDIA-G0}"
  export __GLX_VENDOR_LIBRARY_NAME="''${__GLX_VENDOR_LIBRARY_NAME:-nvidia}"

  # ---- 2) Vulkan cihaz seçimi — VARSAYILAN: KARIŞMA ------------------------
  # DXVK/VKD3D cihazları kendi puanlar ve ayrık GPU'yu tercih eder; doğru
  # davranış zaten varsayılan. __VK_LAYER_NV_optimus VK_LAYER_NV_optimus
  # katmanını sürer — yani cihaz listesini FİLTRELER. Kum havuzunda NVIDIA
  # ICD görünmezse oyun SIFIR Vulkan cihazı görür ve anında kapanır. Bu
  # yüzden varsayılan değil, açık talep:
  #   GR_GPU=nvidia → yalnız dGPU görünsün   (AMD'ye düşen oyunu zorlamak için)
  #   GR_GPU=igpu   → yalnız iGPU görünsün   (hafif oyun / dGPU'yu uyandırma)
  case "''${GR_GPU:-auto}" in
    auto) ;;
    nvidia) export __VK_LAYER_NV_optimus=NVIDIA_only ;;
    igpu)   export __VK_LAYER_NV_optimus=non_NVIDIA_only ;;
    *) gr_say "UYARI: GR_GPU=''${GR_GPU} tanınmadı (auto|nvidia|igpu) — yok sayıldı" ;;
  esac

  # ---- 3) CPU maskesi delme ------------------------------------------------
  # system/kernel/cores.nix systemd manager'ı Zen5c'ye (1,3,5,...,15) kilitler
  # ve bu, fork/exec zinciriyle Steam üzerinden buraya miras kalır. Maske
  # YUMUŞAK (sched_setaffinity) → taskset deler. Varsayılan: tüm 16 CPU.
  #   GR_PIN=big   → 4× Zen5 5.09GHz + SMT (0,2,4,6,8,10,12,14)
  #   GR_PIN=fast  → en hızlı 2 çekirdek + SMT (4,6,12,14); firmware sıralaması
  #                  CPPC 208 / ITMT 203 ile bu dörtlüyü işaret ediyor
  #   GR_PIN=0,2,4 → ham taskset -c listesi
  # NOT (16 Ağu 2026 düzeltmesi): zamanlayıcı hibrit ayrımını BİLİYOR (ITMT
  # açık, Zen5 203 / Zen5c 135) → tek-thread iş zaten TERCİHEN Zen5'e gider.
  # GR_PIN garanti sunar, zorunluluk değil — önce GR_PIN'siz dene.
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

  # GR_CPUMAX işareti — game-perf.service (root) bunu OKUR: varsa PPD
  # performance, yoksa balanced. Varsayılan balanced çünkü CPU ile dGPU
  # paylaşımlı Dynamic Boost bütçesi kullanıyor (GPU-öncelik, sched.nix).
  # game-perf'ten ÖNCE yazılmalı — sırası burada garanti.
  if [ "''${GR_CPUMAX:-0}" = "1" ]; then
    : > "$GR_RUNTIME/gamerun-cpumax" 2>/dev/null || true
  else
    "$GR_CO/rm" -f "$GR_RUNTIME/gamerun-cpumax" 2>/dev/null || true
  fi

  # ---- 5) game-perf.service — DOĞRUDAN, referans sayaçlı -------------------
  # Referans sayacı: her gamerun örneği $GR_STATE altına kendi PID'i adında
  # boş bir dosya bırakır. Çıkışta yalnız CANLI başka örnek kalmadıysa servis
  # durdurulur — iki oyun aynı anda açıkken biri kapanınca diğerinin fanını
  # düşürmesin diye. Ölü PID kayıtları (SIGKILL edilmiş eski örnekler)
  # aynı taramada temizlenir.
  GR_PERF=0
  if [ "''${GR_NOPERF:-0}" = "1" ]; then
    gr_say "game-perf ATLANDI (GR_NOPERF=1) — arıza ikilemesi için"
  elif [ ! -x "$GR_SYSTEMCTL" ]; then
    gr_say "UYARI: $GR_SYSTEMCTL yok — perf zinciri atlandı"
  else
    "$GR_CO/mkdir" -p "$GR_STATE" 2>/dev/null || true

    # ---- SIZINTI SIFIRLAMASI (12 Eyl 2026) — kendi kaydımızdan ÖNCE ----
    # İki ayrı arızayı birden kapatıyor:
    #  (a) Önceki gamerun SIGKILL edilmişse trap koşmadı → game-perf hâlâ "active",
    #      fan turbo'da. Üstelik aero-power-profile ve power-display `is-active
    #      game-perf` görünce fan/affinity yazmayı ATLIYOR, yani fiş/uyanış dâhil
    #      hiçbir olay o turbo'dan çıkaramıyor.
    #  (b) game-perf Type=oneshot + RemainAfterExit → ZATEN aktif bir birime
    #      `systemctl start` demek ExecStart'ı YENİDEN KOŞTURMAZ. Yani sızmış bir
    #      oturumun üstüne açılan yeni oyun, profil/fan/boost ayarlarını hiç almaz.
    # Ölü kayıtları temizleyip canlı bir örnek kalmadıysa birimi kapatıyoruz;
    # hemen aşağıdaki `start` o zaman gerçek bir ExecStart olur.
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
    # SIZMIŞ OTURUMDA `restart`, `stop` + `start` DEĞİL — ÖLÇÜLDÜ 12 Eyl 2026.
    # İlk sürüm stop'layıp sonra start ediyordu ve bu YARIŞA giriyordu: `stop`
    # döndükten sonra da scx.service (PartOf) ~2 sn daha duruyor, o sırada gelen
    # `start` job'ını systemd iptal ediyor. Ölçülen sonuç:
    #   game-perf.service: Main process exited, code=killed, status=15/TERM
    #   game-perf.service: Failed with result 'signal'.
    # Yani sıfırlama, düzeltmeye çalıştığı şeyi bozuyordu. `restart` tek bir job
    # olarak sıralanıyor, çakışma yok — ve `failed` durumdaki birimi de temizler.
    #
    # `failed` de aynı muameleyi görür. Ölçüldü (12 Eyl): çok kısa süren bir oyun
    # (ya da açılır açılmaz çöken bir oyun) stop'u scx daha başlarken tetikliyor ve
    # birim `failed (Result: signal)` kalıyor. İşlevsel zararı yok — ExecStopPost
    # yine koşuyor, fan geri dönüyor — ama kalıntıyı bir sonraki oyunda temizlemek
    # `start`'ın belirsiz bir durumun üstüne binmesinden iyi.
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
    # --no-block: servisin başlaması oyunun açılmasını GECİKTİRMESİN (ilke A).
    # Fiil yukarıda seçildi: normalde `start`, sızmış oturum sıfırlanırken `restart`.
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

  # ---- 6) Oyunu çalıştır ---------------------------------------------------
  # exec DEĞİL, arka plan + wait: temizliğin (ilke D) koşabilmesi için
  # gamerun'ın oyundan sonra hayatta kalması şart. Maliyeti bir bekleyen
  # kabuk süreci — oyun boyunca ~0 CPU.
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
