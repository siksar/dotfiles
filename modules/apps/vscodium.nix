# VSCodium — VS Code'un telemetrisiz/markasız derlemesi (HM)
# Tema + font Stylix'ten otomatik gelir (stylix.targets.vscodium:
# profiles.default'a Stylix tema eklentisi + font userSettings'i gömer) —
# burada renk/font AYARLAMA.
#
# Ayar felsefesi:
#   - Kalıcı ayar → aşağıdaki userSettings'e yaz (rebuild'e dayanır).
#   - GUI'den yapılan ayar → çalışır (mutable-copy sayesinde) ama bir sonraki
#     hms/rebuild'de Stylix+userSettings tabanına sıfırlanır; kalıcı olacaksa
#     buraya taşı.
#   - Eklentiler: tek profil olduğundan mutableExtensionsDir=true (varsayılan) →
#     GUI'den Open VSX ile kurulum serbest, rebuild silmez.
{ lib, ... }:

{
  programs.vscodium = {
    enable = true;
    profiles.default = {
      # Paket nix'ten gelir; uygulama içi güncelleme kontrolü anlamsız
      enableUpdateCheck = false;
      enableExtensionUpdateCheck = false;

      # Minimalist görünüm (kullanıcı isteği 30 Tem, referans ekran görüntüleri).
      # Renk/font YOK — onlar Stylix'ten gelir (dosya başındaki nota bak);
      # buradaki her anahtar yalnız YERLEŞİM/chrome ile ilgili.
      userSettings = {
        #### Chrome kaldırma ####
        # Sol dikey ikon şeridi tamamen gider. BEDELİ: panellere yalnız klavyeden
        # ulaşılır — Ctrl+Shift+E explorer, F arama, G git, X eklentiler, Ctrl+B
        # paneli aç/kapa. Fare erişimi istersen "hidden" → "top" (tek satır dönüş).
        "workbench.activityBar.location" = "hidden";
        "workbench.statusBar.visible" = false;
        "breadcrumbs.enabled" = false;
        "editor.minimap.enabled" = false;
        "editor.stickyScroll.enabled" = false;
        "workbench.layoutControl.enabled" = false; # sağ üst yerleşim ikonları
        "workbench.startupEditor" = "none"; # Welcome sekmesi yerine boş

        # Girinti kılavuzları BİLİNÇLİ olarak açık bırakıldı (varsayılan) —
        # referans görüntüde duruyor ve iç içe blokta okumayı kolaylaştırıyor.

        #### Pencere süslemesi compositor'a bırakılır ####
        # VSCodium kendi başlık çubuğunu çizmez → pencere kenarı doğrudan
        # Hyprland'ın border + rounding'ine dayanır (hyprland-rice/lua/rules.lua,
        # "vscodium-chrome" kuralı). titleBarStyle="native" DEĞİL: Wayland'de
        # native, menü çubuğunu pencerenin İÇİNE ayrı bir satır olarak koyuyor —
        # tam istenmeyen şey. custom + never ikisini birden halleder.
        "window.titleBarStyle" = "custom";
        "window.customTitleBarVisibility" = "never";
        "window.menuBarVisibility" = "toggle"; # menü gizli, Alt ile gelir

        #### Nefes payı ####
        "editor.padding.top" = 12;
        "editor.lineHeight" = 1.6; # <8 ⇒ font boyutu çarpanı (VS Code kuralı)
        "editor.fontLigatures" = true; # JetBrainsMono'nun ligatürleri; font Stylix'ten
        "editor.cursorBlinking" = "smooth";
        "editor.cursorSmoothCaretAnimation" = "on";
        "editor.smoothScrolling" = true;
        "workbench.list.smoothScrolling" = true;
        "editor.overviewRulerBorder" = false; # sağ işaret şeridinin çerçevesi
        "editor.hideCursorInOverviewRuler" = true;
        "editor.scrollbar.verticalScrollbarSize" = 8; # ince kaydırma çubuğu
      };
    };
  };

  # Stylix userSettings gömdüğü için settings.json HM symlink'i olur; VSCodium
  # GUI ayar editörü de bu dosyaya yazar → symlink yerine mutable-copy
  # (vesktop.nix deseni), bayat backup checkLinkTargets'tan önce silinir.
  home.activation.vscodiumCleanBackups = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    run rm -f "$HOME/.config/VSCodium/User/settings.json.hm-backup"
  '';
  home.activation.vscodiumMutableConfigs = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    f="$HOME/.config/VSCodium/User/settings.json"
    if [ -L "$f" ]; then
      run cp --remove-destination "$(readlink -f "$f")" "$f"
      run chmod u+w "$f"
    fi
  '';
}
