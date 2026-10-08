# MC OpenGL: dGPU için __GLX_VENDOR_LIBRARY_NAME=nvidia şart — gamerun verir.
{ lib, pkgs, ... }:

let
  # mc-run: __GL_THREADED_OPTIMIZATIONS=0 Sodium+NVIDIA FPS düzeltmesi; başka GL
  # oyunlarında ters etki → yalnız MC'ye scope'lu, gamerun'a koyma.
  mc-run = pkgs.writeShellScriptBin "mc-run" ''
    export __GL_THREADED_OPTIMIZATIONS="''${__GL_THREADED_OPTIMIZATIONS:-0}"
    exec gamerun "$@"
  '';
in
{
  home.packages = [ pkgs.prismlauncher mc-run ];

  # Aikar seti; sabit heap + MaxGCPauseMillis=200 bilinçli (50 ve heap resize takılıyordu).
  # AutomaticJavaDownload=false: indirilen generic JDK NixOS'ta çalışmaz.
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

  # Prism cfg'yi runtime'da yazar → mutable-copy.
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
