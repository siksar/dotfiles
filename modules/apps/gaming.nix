# Oyun (HM katmanı): gamerun sarmalayıcısı + MangoHud yapılandırması
# Steam launch options: gamerun %command%   (ayrıntı: docs/gaming.md)
{ pkgs, ... }:

let
  gamerun = pkgs.writeShellScriptBin "gamerun" ''
    # gamerun — dGPU offload + DLSS 4.5 + Reflex + ntsync + MangoHud + gamemode
    # Kullanım (Steam launch options): gamerun %command%
    # Oyun başına ezme: "VAR=değer gamerun %command%" (tüm varsayılanlar :- ile)
    #
    # Opt-in anahtarlar:
    #   GR_MFG=2..6   → DLSS Multi Frame Generation (2x..6x; FG'yi oyun menüsünden aç)
    #   GR_DYNFG=165  → Dinamik MFG: hedef FPS'e otomatik çarpan (GR_MFG'yi ezer)
    #   GR_SMOOTH=1   → sürücü Smooth Motion (DLSS'siz oyunlara framegen; FG/MFG ile BİRLEŞMEZ)
    #   GR_WL=1       → Proton Wayland (deneysel; Steam Overlay/Input bozulur)
    #   GR_NOHUD=1    → MangoHud tamamen kapalı (F12 de çalışmaz)
    #   GR_PIN=big    → yalnız Zen5 "big" çekirdekler (HOI4 gibi tek-çekirdek oyunlar)
    #   GR_PIN=fast   → yalnız en hızlı 2 çekirdek (prefcore 208: cpu4/6 + SMT)
    #   GR_PIN=0,2,4  → özel CPU listesi (taskset -c biçimi)

    # --- dGPU PRIME offload (RTX 5060) ---
    export __NV_PRIME_RENDER_OFFLOAD="''${__NV_PRIME_RENDER_OFFLOAD:-1}"
    export __NV_PRIME_RENDER_OFFLOAD_PROVIDER="''${__NV_PRIME_RENDER_OFFLOAD_PROVIDER:-NVIDIA-G0}"
    export __GLX_VENDOR_LIBRARY_NAME="''${__GLX_VENDOR_LIBRARY_NAME:-nvidia}"
    export __VK_LAYER_NV_optimus="''${__VK_LAYER_NV_optimus:-NVIDIA_only}"

    # --- DLSS 4.5: NGX updater (en yeni DLL'leri indirir) + SR/RR/FG override ---
    # render_preset_latest: DLSS 4.5'te "latest = önerilen" (2. nesil transformer)
    export PROTON_ENABLE_NGX_UPDATER="''${PROTON_ENABLE_NGX_UPDATER:-1}"
    export DXVK_NVAPI_DRS_NGX_DLSS_SR_OVERRIDE="''${DXVK_NVAPI_DRS_NGX_DLSS_SR_OVERRIDE:-on}"
    export DXVK_NVAPI_DRS_NGX_DLSS_RR_OVERRIDE="''${DXVK_NVAPI_DRS_NGX_DLSS_RR_OVERRIDE:-on}"
    export DXVK_NVAPI_DRS_NGX_DLSS_FG_OVERRIDE="''${DXVK_NVAPI_DRS_NGX_DLSS_FG_OVERRIDE:-on}"
    export DXVK_NVAPI_DRS_NGX_DLSS_SR_OVERRIDE_RENDER_PRESET_SELECTION="''${DXVK_NVAPI_DRS_NGX_DLSS_SR_OVERRIDE_RENDER_PRESET_SELECTION:-render_preset_latest}"
    export DXVK_NVAPI_DRS_NGX_DLSS_RR_OVERRIDE_RENDER_PRESET_SELECTION="''${DXVK_NVAPI_DRS_NGX_DLSS_RR_OVERRIDE_RENDER_PRESET_SELECTION:-render_preset_latest}"

    # --- Gecikme + CPU senkron ---
    export DXVK_NVAPI_VKREFLEX="''${DXVK_NVAPI_VKREFLEX:-1}"  # Reflex (VK_NV_low_latency2)
    export PROTON_USE_NTSYNC="''${PROTON_USE_NTSYNC:-1}"      # sorunlu oyunda =0 ile ez

    # --- HUD + shader cache ---
    export MANGOHUD="''${MANGOHUD:-1}"  # no_display=true → görünmez, F12 açar
    export __GL_SHADER_DISK_CACHE_SKIP_CLEANUP="''${__GL_SHADER_DISK_CACHE_SKIP_CLEANUP:-1}"

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

    [ "''${GR_WL:-0}" = "1" ] && export PROTON_ENABLE_WAYLAND=1
    [ "''${GR_NOHUD:-0}" = "1" ] && export MANGOHUD=0

    # --- CPU pinleme (heterojen Zen5/Zen5c — Ryzen AI 7 350) ---
    # big  = 4× Zen5 5.09GHz (cpu 0,2,4,6 + SMT 8,10,12,14); Zen5c 3.5GHz dışarıda.
    # Tek-çekirdek sim oyunlarında (HOI4/Stellaris/Factorio) ana thread'in
    # Zen5c'ye düşmesini engeller (%31 frekans farkı). Çoğu oyunda GEREKMEZ:
    # prefcore + scx_lavd --performance zaten big'leri önceler.
    if [ -n "''${GR_PIN:-}" ]; then
      case "$GR_PIN" in
        big)  GR_CPUS="0,2,4,6,8,10,12,14" ;;
        fast) GR_CPUS="4,6,12,14" ;;
        *)    GR_CPUS="$GR_PIN" ;;
      esac
      exec ${pkgs.util-linux}/bin/taskset -c "$GR_CPUS" ${pkgs.gamemode}/bin/gamemoderun "$@"
    fi

    exec ${pkgs.gamemode}/bin/gamemoderun "$@"
  '';
in
{
  home.packages = [ gamerun ];

  # MangoHud: varsayılan GİZLİ başlar, F12 ile oyun içinde aç/kapa.
  # NOT: Steam'in varsayılan screenshot tuşu da F12 → Steam Ayarlar → Oyun İçi
  # bölümünden screenshot tuşunu taşı (örn. F11), yoksa ikisi birden tetiklenir.
  # Proton oyunları (SLR konteyneri) host'taki ~/.config/MangoHud/MangoHud.conf'u
  # okur → bu ayarlar hepsinde geçerli; gamescope --mangoapp'ta da aynı F12.
  programs.mangohud = {
    enable = true;
    settings = {
      no_display = true;   # başlangıçta görünmez (katman yüklü, maliyet ihmal edilebilir)
      toggle_hud = "F12";
      position = "top-left";

      # Kritik metrikler: %1 low + %0.1 low + watt
      fps = true;
      fps_metrics = "avg,0.01,0.001"; # ortalama, %1 low, %0.1 low
      cpu_power = true;               # CPU paket watt
      gpu_power = true;               # dGPU watt

      frame_timing = true;            # frametime grafiği
      cpu_stats = true;
      cpu_temp = true;
      cpu_mhz = true;
      gpu_stats = true;
      gpu_temp = true;
      gpu_core_clock = true;
      vram = true;
      ram = true;
      engine_version = true;
      wine = true;
      winesync = true;                # ntsync/fsync göstergesi
      gamemode = true;                # GameMode aktiflik göstergesi
      vulkan_driver = true;
    };
  };
}
