# Minecraft — Prism Launcher + mc-run→gamerun zinciri + JVM optimizasyonu
# Prism her instance'ı WrapperCommand=mc-run ile başlatır → MC'ye özel GL env +
# gamerun (dGPU PRIME offload) + gamemode (renice) + game-perf.service (scx_lavd,
# AC'de 0xED + turbo fan) otomatik devrede.
# MC OpenGL olduğundan gamerun'ın DLSS/Reflex/ntsync env'leri etkisiz-zararsız.
# Ayrıntı ve gerekçeler: docs/gaming.md "Minecraft (Prism Launcher)" bölümü.
{ lib, pkgs, ... }:

let
  # mc-run: MC'ye ÖZEL OpenGL env'i (yalnız Prism yolunda; Steam'e sızmaz), sonra
  # gamerun'a devreder. Neden ayrı sarmalayıcı? __GL_THREADED_OPTIMIZATIONS=0
  # Minecraft+Sodium+NVIDIA'da FPS düzeltmesi (sürücü Prism ile başlatılan MC'yi
  # tanıyamıyor → threaded-GL opt yanlış devreye girip FPS düşürüyor; Sodium wiki
  # Driver-Compatibility + issue #1830). Ama bu değişken bazı OpenGL oyunlarında
  # TERS etki yapar → global veya gamerun'a KOYULMAZ, yalnız MC'ye scope'lanır.
  # PRIME offload env'leri gamerun'dan miras kalır (mc-run onu exec ettiği için).
  mc-run = pkgs.writeShellScriptBin "mc-run" ''
    export __GL_THREADED_OPTIMIZATIONS="''${__GL_THREADED_OPTIMIZATIONS:-0}"
    exec gamerun "$@"
  '';
in
{
  # Sarmalayıcı jdk8/17/21/25'i PRISMLAUNCHER_JAVA_PATHS'e ekler → ayrı Java
  # paketi kurulmaz; AutomaticJavaSwitch instance'ın MC sürümüne göre seçer.
  # mc-run: WrapperCommand hedefi (gamerun'ı PATH'ten çağırır).
  home.packages = [ pkgs.prismlauncher mc-run ];

  # JVM bayrakları: Aikar flag seti (modlu-MC standardı; Java 8→25 hepsinde geçerli,
  # ZGC gibi 21+ bayrağı YOK — JvmArgs global). Periyodik GC hitch'ini hedefler (hem
  # VulkanMod hem Sodium modpack'lerinde görüldü → render'dan bağımsız, GC kaynaklı):
  #   • sabit heap (Min=Max=8192) → JVM'in dinamik heap resize duraklaması biter;
  #   • +AlwaysPreTouch → tüm heap başta commit (kısa açılış gecikmesi, oyun-içi
  #     commit hitch'i yok);
  #   • MaxGCPauseMillis=200 (50 DEĞİL) → 50 daha SIK, küçük GC yapıp overhead/hitch
  #     ekliyordu; Aikar felsefesi az sayıda iyi-yönetilen GC.
  # AutomaticJavaDownload=false: Prism'in indirdiği generic binary NixOS'ta çalışmaz
  # (dinamik linker yok). MaxMemAlloc: çok ağır modpack instance ayarlarından
  # yükseltilebilir (Settings → Java sekmesi; per-instance Min/Max'i ezer).
  xdg.dataFile."PrismLauncher/prismlauncher.cfg".text = ''
    [General]
    AutomaticJavaSwitch=true
    AutomaticJavaDownload=false
    IgnoreJavaWizard=true
    MinMemAlloc=8192
    MaxMemAlloc=8192
    JvmArgs=-XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200 -XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC -XX:+AlwaysPreTouch -XX:G1NewSizePercent=30 -XX:G1MaxNewSizePercent=40 -XX:G1HeapRegionSize=8M -XX:G1ReservePercent=20 -XX:G1HeapWastePercent=5 -XX:G1MixedGCCountTarget=4 -XX:InitiatingHeapOccupancyPercent=15 -XX:G1MixedGCLiveThresholdPercent=90 -XX:G1RSetUpdatingPauseTimePercent=5 -XX:SurvivorRatio=32 -XX:+PerfDisableSharedMem -XX:MaxTenuringThreshold=1
    WrapperCommand=mc-run
  '';

  # Prism cfg'yi runtime'da kendisi de yazar (pencere geometrisi vb.) → HM
  # symlink'i yerine mutable-copy (vesktop.nix'teki desen), bayat backup'lar
  # checkLinkTargets'tan önce silinir.
  home.activation.prismCleanBackups = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    run rm -f "$HOME/.local/share/PrismLauncher/prismlauncher.cfg.hm-backup"
  '';
  home.activation.prismMutableConfig = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    f="$HOME/.local/share/PrismLauncher/prismlauncher.cfg"
    if [ -L "$f" ]; then
      run cp --remove-destination "$(readlink -f "$f")" "$f"
      run chmod u+w "$f"
    fi
  '';
}
