{ pkgs, inputs, ... }:

{
  programs.steam = {
    enable = true;
    # Proton: proton-ge-bin varsayılan; proton-cachyos inatçı DX12 oyunları için.
    extraCompatPackages = [
      pkgs.proton-ge-bin
      inputs.chaotic.packages.${pkgs.stdenv.hostPlatform.system}.proton-cachyos
    ];
    protontricks.enable = true;
    # gamerun'ı pressure-vessel kum havuzuna koyar (/usr/bin/gamerun).
    extraPackages = [ (import ../lib/gamerun.nix { inherit pkgs; }) ];
  };

  # Proton-CachyOS binary cache (chaotic).
  nix.settings = {
    substituters = [ "https://nyx-cache.chaotic.cx/" ];
    trusted-public-keys = [ "nyx-cache.chaotic.cx:dJxTrgMC3V3cFfyIiBQDQorG6k1LsqurH/srpMSq7qk=" ];
  };
}
