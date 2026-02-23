# Quickshell (dotfiles)

QML/JS ile yapılandırılabilir Wayland compositor. Tam açıklama: [docs/QUICKSHELL.md](../docs/QUICKSHELL.md).

## Nix’te kullanım

- **Paket**: `nixpkgs.quickshell` (0.2.1)
- **Aktif etmek**: `base/modules/quickshell.nix` var; flake’e import edip `quickshell.enable = true` yapabilirsin.
- **Config**: Bu dizindeki QML/JS dosyaları `~/.config/quickshell/` ile bağlanabilir (home.file).

## Hyprland ile birlikte

Şu an varsayılan oturum Hyprland. Quickshell’i aynı makinede denemek için:

- Sadece paketi aç: `quickshell` komutuyla manuel çalıştırırsın.
- Veya GreetD’de ikinci session ekle: `Quickshell` seçeneği (modules/quickshell.nix’te tanımlı).

## Config örneği

`~/.config/quickshell/main.qml` (veya bu dizine koyup Nix ile link’le):

- [Quickshell docs](https://invent.kde.org/nickshanks/quickshell) veya örnek config’lere bak.

Tema: Stylix renklerini QML’e taşımak için Nix’te `stylix.base16Scheme` okuyup bir JSON/JS dosyası üretip QML’den kullanılabilir (ileride eklenebilir).
