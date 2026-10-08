# RPCS3 + shadPS4; emu-run → gamerun. dGPU: GR_GPU=nvidia emu-run rpcs3.
{ pkgs, ... }:

let
  emu-run = pkgs.writeShellScriptBin "emu-run" ''
    # emu-run — dGPU PRIME offload + gamemode zincirine emülatör delegesi
    # Kullanım: emu-run {rpcs3|shadps4} [argümanlar...]
    # PRIME env + gamemode gamerun'dan miras (exec eder). Proton env'leri native
    # Vulkan emülatörlerinde no-op → RPCS3/shadps4'de zararsız.
    case "$1" in
      rpcs3)   shift; exec gamerun ${pkgs.rpcs3}/bin/rpcs3 "$@" ;;
      shadps4) shift; exec gamerun ${pkgs.shadps4}/bin/shadps4 "$@" ;;
      *)
        echo "emu-run: bilinmeyen emülatör: $1" >&2
        echo "Kullanım: emu-run {rpcs3|shadps4} [argümanlar...]" >&2
        exit 2
        ;;
    esac
  '';
in
{
  home.packages = [
    pkgs.rpcs3
    pkgs.shadps4
    emu-run
  ];

  # .desktop başlatıcıları PRIME env'i vermez (iGPU); dGPU için terminalden emu-run.
}
