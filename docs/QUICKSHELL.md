# Quickshell

## Nedir?

**Quickshell**, Wayland için QML ve JavaScript ile yapılandırılabilir bir **tiling compositor / shell çerçevesi**. Hyprland/Sway gibi tam bir compositor; pencereleri kendisi yönetir. Farkı: yapılandırma Nix veya C++ yerine **QML + JS** ile yapılır.

- **Proje**: [KDE Invent – Quickshell](https://invent.kde.org/nickshanks/quickshell) (eski adıyla qt-quickshell)
- **Dil**: C++/Qt tabanı, kullanıcı tarafı QML/JS
- **Çıktı**: Tek bir Wayland compositor (X11/Wayland client değil)

## Hyprland / Noctalia ile fark

| | Hyprland | Quickshell |
|---|----------|------------|
| Config | C benzeri (hyprland.conf) | QML + JavaScript |
| Bar/Shell | Ayrı (Waybar, Noctalia, Caelestia) | Bar/panel QML ile compositor’ın parçası |
| Tiling | Evet | Evet (kendi tiling modeli) |

**Noctalia Shell** ve **Caelestia** aslında Hyprland üzerinde çalışan “desktop shell” (launcher, bar, control center). Quickshell ise **compositor’ın kendisi**; bar ve tüm UI QML ile tek projede.

## NixOS’ta kullanım

- `nixpkgs` içinde `quickshell` (veya `qt6.quickshell`) paketi olabilir; yoksa flake/overlay ile derlenebilir.
- Oturum: `quickshell` (veya `qs`) çalıştırılır; GreetD/session’da Hyprland yerine Quickshell seçilir.
- Config dizini: `~/.config/quickshell/` (QML/JS dosyaları).

## Dotfiles’ta konum (plan)

- **Konfigürasyon**: `dotfiles/quickshell/` (QML/JS dosyaları)
- **Nix**: flake input veya `base/modules/quickshell.nix` ile paket + session
- **Tema**: Stylix doğrudan uygulanamaz (Quickshell GTK/terminal değil); renkleri Stylix base16’dan alıp QML’e aktaran bir Nix modülü yazılabilir.

## Altından kalkılabilir mi?

Evet. Adımlar:

1. **Paket**: nixpkgs’ta `quickshell` var mı kontrol et; yoksa KDE Invent’ten flake/overlay ile al.
2. **Session**: `programs.quickshell.enable` veya `services.displayManager` ile Quickshell’i giriş oturumu olarak tanımla.
3. **Config**: `~/.config/quickshell/` içeriğini `dotfiles/quickshell/` ile yönet (home.file veya xdg.configFile).
4. **Tema**: İsteğe bağlı; Stylix base16 renklerini Nix’te okuyup QML’e enjekte eden küçük bir script/modül.

İstersen sıradaki adım: flake’e Quickshell input’u ekleyip, `base/modules/quickshell.nix` ile paket + GreetD session’ı bağlamak.
