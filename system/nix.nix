{ ... }:

{
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];

    # trusted: flake nixConfig önbellekleri (extra-substituters) için şart.
    trusted-users = [ "root" "@wheel" ];

    # Üçüncü taraf önbellek düşerse switch takılmasın: 5 s'de vazgeç, fallback.
    connect-timeout = 5;
    fallback = true;

    download-buffer-size = 256 * 1024 * 1024;

    warn-dirty = false;

    auto-optimise-store = true;
  };

  nix.optimise = {
    automatic = true;
    dates = [ "weekly" ];
  };

  nix.channel.enable = false;

  programs.nh = {
    enable = true;
    clean.enable = true;
    clean.extraArgs = "--keep-since 4d --keep 3";
    flake = "/home/zixar/nixos-zixar";
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  # nix-ld: FHS varsayan ikililer (npm/pip yerel modülleri, VS Code sunucusu, uv Python'ları).
  programs.nix-ld.enable = true;
}
