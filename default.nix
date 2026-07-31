# Flake-öncesi araçlar için uyumluluk kapısı.
#
# Gerçek tanım flake.nix'te; burası yalnız ona bir giriş. Faydası: `nix repl ./`
# ve `nix-instantiate` gibi flake bayrağı almayan yollar config'i görebilsin —
# ör. bir seçeneğin değerini kurcalarken:
#
#   nix repl ./
#   nix-repl> nixosConfigurations.nixos.config.boot.kernelParams
#   nix-repl> homeConfigurations."zixar".config.home.packages
#
# Rebuild için KULLANILMAZ; onun yolu README.md'de (`nh os switch`).
#
# UYARI: getFlake git'in İZLEDİĞİ dosyaları görür. Yeni bir dosya ekleyip
# `git add` etmediysen burada "file not found" alırsın — flake yolunda da aynı.
(builtins.getFlake (toString ./.)).outputs
