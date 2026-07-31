# Rofi 2.0 (Wayland yerli) — launcher teması + duvar kağıdı grid'i.
#
# UYARI 1: rofi 2.0 `linear-gradient(...)` İÇİNDE @değişken ayrıştıramaz ve
# yerel hata vermez — TÜM tema dosyasını reddedip sessizce dahili Solarized
# LIGHT temasına düşer. themes.nix bu yüzden hex'leri build-time'da gömer.
# Değişiklik sonrası `rofi -no-config -theme <dosya> -dump-theme` çalıştır ve
# STDERR'e bak; temiz bir stdout dökümü kanıt DEĞİL, fallback de temiz döker.
#
# UYARI 2: programs.rofi.theme MUTLAK YOL DİZESİ olmalı — türev (attrset)
# verilirse HM onu rasi ağacı sanıp "Unhandled value type set" ile patlar.
{ config, lib, pkgs, ... }:

let
  cfg = config.desktop.hyprland;
  cfgHome = config.xdg.configHome;

  # --- Rofi teması (adi1090x/rofi type-5/style-4 portu) ---
  # style4:     üst kaynak + mono renk katmanı birleştirilmiş tek .rasi
  # monoColors: aynı paletin @değişken sürümü (wallpaper-grid.rasi import eder)
  # İkisi de waybar-mono.css'ten beslenir — waybar temalarıyla tek renk kaynağı.
  rofiThemes = import ./themes.nix { inherit pkgs lib; };
in
{
  config = lib.mkIf cfg.enable {
    #### Rofi (2.0 — Wayland yerli) ####
    programs.rofi = {
      enable = true;
      terminal = "ghostty";
      font = "JetBrainsMono Nerd Font 12";
      extraConfig."show-icons" = true;
      # DİKKAT: buraya writeText türevi (attrset) verilemez — HM modülü onu
      # rasi attrset'i sanıp çevirmeye kalkar ("Unhandled value type set").
      # Mutlak yol dizesi ver; dosyanın kendisi aşağıda xdg.configFile'da.
      theme = "${cfgHome}/rofi/type-5-style-4.rasi";
    };

    xdg.configFile = {
      # + mono renk katmanı build-time'da TEK dosyada birleştirilir
      # (rofi-themes.nix); programs.rofi.theme buna mutlak yolla işaret eder.
      # Renkler literal hex olarak gömülü, @import YOK — rofi 2.0 gradient
      # içinde @değişken'i ayrıştıramıyor (gerekçe rofi-themes.nix'te).
      "rofi/type-5-style-4.rasi".source = rofiThemes.style4;

      # waybar-mono paletinin @değişken sürümü — wallpaper-grid.rasi bunu
      # import eder. matugen'in colors.rasi'siyle AYNI değişken adlarını taşır:
      # rofi'yi duvar kağıdına göre değişen renklere döndürmek istersen
      # aşağıdaki import satırında dosya adını colors.rasi yapman yeter.
      "rofi/mono-colors.rasi".source = rofiThemes.monoColors;

      # wallpaper-picker'ın ikon grid teması. @import MUTLAK yol: bu dosya
      # store'a symlink'lenir, göreli import store dizininde arardı.
      "rofi/wallpaper-grid.rasi".text = ''
        @import "${cfgHome}/rofi/mono-colors.rasi"

        /* Launcher (type-5/style-4) ile aynı mono paleti — waybar'ın V-temaları
         * ve bu grid tek renk ailesinde kalsın diye. rofi 2.0'ın dahili
         * varsayılan teması Solarized LIGHT olduğundan * tabanı + element
         * durumları açıkça override edilmezse grid öğeleri beyaz görünür
         * (kanıt: rofi -dump-theme). */
        * {
            background-color: @bg;
            text-color: @fg;
        }
        window {
            width: 70%;
            background-color: @bg;
            border: 2px;
            border-color: @accent;
            border-radius: 12px;
            padding: 16px;
        }
        mainbox { background-color: transparent; }
        inputbar {
            children: [ prompt, entry ];
            background-color: @bg-alt;
            text-color: @fg;
            padding: 8px;
            border-radius: 8px;
        }
        prompt { text-color: @accent; background-color: transparent; }
        entry  { text-color: @fg; background-color: transparent; placeholder-color: @fg-dim; }
        listview {
            columns: 4;
            lines: 2;
            spacing: 12px;
            padding: 12px 0px 0px;
            background-color: transparent;
        }
        element {
            orientation: vertical;
            padding: 8px;
            border-radius: 10px;
            background-color: transparent;
            text-color: @fg-dim;
        }
        element normal.normal    { background-color: transparent; text-color: @fg-dim; }
        element alternate.normal { background-color: transparent; text-color: @fg-dim; }
        element selected.normal  { background-color: @accent;     text-color: @on-accent; }
        element-icon { background-color: transparent; size: 160px; }
        element-text {
            background-color: transparent;
            horizontal-align: 0.5;
            text-color: inherit;
        }
      '';
    };
  };
}
