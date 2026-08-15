# Caelestia — Quickshell tabanlı masaüstü kabuğu (bar/launcher/bildirim/kilit/idle)
# + cli (runtime Material You tema motoru). Eski waybar+rofi+swaync+matugen rice'ının
# yerini alır — bkz. home/desktop/CLAUDE.md için tuzaklar, Documentation/desktop.md
# için tasarım.
#
# Tema geçişi rebuild İSTEMEZ: launcher'da ">scheme <ad>" ile anlık değişir.
# Şema seçimi ~/.local/state/caelestia/scheme.json'da kalıcıdır.
{ config, lib, pkgs, inputs, ... }:

let
  cfg = config.desktop.hyprland;
  system = pkgs.stdenv.hostPlatform.system;

  # Şema geçişi sonrası koşan hook: klavye RGB'yi yeni birincil renge senkronlar.
  # Sözleşme keyboard-rgb tarafında sabit — kbd-rgb çıplak hex bekliyor
  # (system/drivers/input/keyboard-rgb/src/main.rs), bu yüzden templates/kbd-color
  # {{ primary.hex }} (# YOK, tıpkı eski matugen sözleşmesiyle aynı) kullanıyor.
  # DİKKAT: postHook stderr=DEVNULL ile koşar — başarısız hook SESSİZDİR.
  themePostHook = pkgs.writeShellScript "caelestia-theme-hook" ''
    c=$(cat "$HOME/.local/state/caelestia/theme/kbd-color" 2>/dev/null) || exit 0
    kbd-rgb set "$c" >/dev/null 2>&1 || true
  '';

  # Özel şemalar paket verisine gömülür — böylece `caelestia scheme set -n <isim>`
  # ve launcher'daki ">scheme" seçici görür. Kullanıcı seviyesinde şema dizini
  # upstream'de YOK (scheme.py get_scheme_names yalnız paketlenmiş dizini tarar),
  # tek yol paket yaması.
  #
  # NEDEN postInstall, postPatch DEĞİL (15 Ağu 2026, pahalı ders): upstream kendi
  # default.nix'inde patchPhase'i DÜZ STRING olarak tanımlıyor ve içinde runHook
  # YOK. stdenv ise fazı `eval "${!curPhase:-$curPhase}"` ile çağırıyor — attribute
  # varsa varsayılan faz FONKSİYONU hiç koşmaz, dolayısıyla o fonksiyonun içindeki
  # prePatch/postPatch hook'larının İKİSİ birden ölüdür. postPatch'e yazılan
  # enjeksiyon hata vermeden, build yeşil geçerek yok sayıldı: 9 Ağu'dan 15 Ağu'ya
  # kadar 7 şemanın hiçbiri pakete girmedi. postInstall CANLI, çünkü install fazını
  # pypa-install-hook sağlıyor ve o `runHook postInstall` çağırıyor — kanıtı
  # upstream'in kendi installShellCompletion'ı, aynı build'de çalışmış durumda.
  #
  # Hedef yol utils/paths.py'den: cli_data_dir = __file__/../../data, yani kurulu
  # site-packages içi. Format doğrulandı: "key HEX" (tek boşluk, # yok, küçük harf) —
  # anahtar adları ve SIRASI upstream stok şemalarıyla birebir; schemes/*.txt
  # rice/caelestia dalından BİREBİR kopya (dönüşüm YAPILMADI — base16 çevrimi
  # lossy: 110 anahtarın yalnız 16'sı taşınıyor, bkz. lib/theme.nix:40).
  cli-pkg =
    (inputs.caelestia-cli.packages.${system}.default.override {
      discordBin = "vesktop";
    }).overrideAttrs (old: {
      postInstall = (old.postInstall or "") + ''

        sp=$(echo "$out"/lib/python3*/site-packages/caelestia/data/schemes)
        [ -d "$sp" ] || { echo "HATA: şema dizini bulunamadı ($sp) — kurulum düzeni değişmiş"; exit 1; }
        for f in ${./schemes}/*.txt; do
          name=$(basename "$f" .txt)
          mkdir -p "$sp/$name/main"
          cp "$f" "$sp/$name/main/dark.txt"
        done
      '';
      # Sessizliği kıran adım: enjeksiyon KOPYADAN FARKLI bir fazda doğrulanır, ki
      # tek bir upstream değişikliği (bir fazın string olarak tanımlanması) ikisini
      # birden sessizce düşüremesin — üstteki hata tam olarak böyle gizlenmişti.
      postFixup = (old.postFixup or "") + ''

        sp=$(echo "$out"/lib/python3*/site-packages/caelestia/data/schemes)
        for f in ${./schemes}/*.txt; do
          name=$(basename "$f" .txt)
          [ -f "$sp/$name/main/dark.txt" ] || {
            echo "HATA: '$name' şeması pakete girmedi (bakılan dizin: $sp)"
            exit 1
          }
        done
      '';
    });

  # Gömülü CLI de bizimki olmalı — yoksa launcher'ın ">scheme" seçicisi ve
  # `caelestia scheme list` özel şemaları göremez (wrapper PATH'i upstream cli'a
  # düşer).
  shell-pkg = inputs.caelestia-shell.packages.${system}.with-cli.override {
    caelestia-cli = cli-pkg;
  };

  # İlk açılış varsayılanı — runtime seçimini ASLA ezmez (state varsa dokunmaz).
  # exec-once DEĞİL ExecStartPre: shell kendi ilk state'ini yazmadan ÖNCE koşması
  # garanti olsun, aksi halde CLI'ın kod-varsayılanı catppuccin kazanır.
  # dynamic = duvar kağıdından Material You üretir — eski matugen zincirinin
  # (SUPER+T → wallpaper → renk üretimi) en yakın karşılığı.
  defaultsGuard = pkgs.writeShellScript "caelestia-defaults" ''
    state="$HOME/.local/state/caelestia"
    if [ ! -f "$state/scheme.json" ]; then
      ${cli-pkg}/bin/caelestia wallpaper -f "$HOME/Pictures/Wallpapers/misty-forest.jpg" || true
      ${cli-pkg}/bin/caelestia scheme set -n dynamic || true
    fi
  '';
in
{
  # imports şart-dışı olmalı (mkIf içinde olamaz) — config = lib.mkIf ... altında
  # gövde kapatılıyor.
  imports = [ inputs.caelestia-shell.homeManagerModules.default ];
  # DİKKAT: `homeModules.default` YOK — bazı üçüncü taraf örnekler bunu yazar,
  # eval hatası verir. Doğru ad `homeManagerModules.default`.

  config = lib.mkIf cfg.enable {
    # CLI'ın yazdığı her yüzey için Stylix'i kapat — iki renk yazarı olamaz.
    # Stylix font/imleç/build-time taban olarak kalır (lib/theme.nix paleti
    # yalnız Caelestia'nın dokunmadığı hedefleri besler).
    stylix.targets = {
      hyprland.enable = false; # CLI hypr/scheme/current.conf yazıyor
      gtk.enable = false; # CLI gtk.css + dconf yazıyor
      qt.enable = false; # CLI qt5ct/qt6ct colors yazıyor
      btop.enable = false;
      fuzzel.enable = false;
      ghostty.enable = false; # CLI OSC dizileriyle canlı boyuyor (enableTerm)
    };

    home.packages = with pkgs; [
      qt6Packages.qt6ct # Qt tema uygulaması — QT_QPA_PLATFORMTHEME aşağıda
      adw-gtk3
      papirus-icon-theme
      # fuzzel/cliphist CLI'ın kendi runtimeDeps'inde geliyor — elle EKLEME.
      # Fontlar (material-symbols, rubik, CaskaydiaCove NF) shell wrapper'ının
      # FONTCONFIG_FILE'ıyla geliyor — fonts.packages'a dokunma.
    ];

    home.sessionVariables.QT_QPA_PLATFORMTHEME = "qt6ct";

    # Duvar kağıtları — eski theme/matugen.nix'ten taşındı.
    home.file."Pictures/Wallpapers" = {
      source = ../../../lib/wallpapers;
      recursive = true;
    };

    programs.caelestia = {
      enable = true;
      package = shell-pkg;

      systemd = {
        enable = true;
        # Repo kuralı: jenerik graphical-session.target DEĞİL — bu yalnız bu
        # oturum için aktive olur (bkz. home/desktop/CLAUDE.md).
        target = "hyprland-session.target";
        # Qt/EGL'i iGPU'ya kilitle. AQ_DRM_DEVICES yalnız aquamarine'i (Hyprland
        # compositor'ı) bağlar, Qt istemcisini BAĞLAMAZ — bu olmadan Quickshell'in
        # EGL enumerasyonu NVIDIA düğümünü açıp dGPU'yu D3cold'dan uyandırabilir.
        # /run/opengl-driver/share/glvnd/egl_vendor.d/50_mesa.json varlığı
        # doğrulandı.
        environment = [
          "__GLX_VENDOR_LIBRARY_NAME=mesa"
          "__EGL_VENDOR_LIBRARY_FILENAMES=/run/opengl-driver/share/glvnd/egl_vendor.d/50_mesa.json"
        ];
      };

      settings = {
        # --- 4.28 W idle bütçesi: idle'da hiçbir şey dönmesin ---
        services.gpuType = "None"; # nvidia-smi fork'unu kökten kes (Auto/NVIDIA
        # her tick'te — varsayılan 1000ms — bir kez nvidia-smi fork eder ve dGPU'yu
        # uyandırır; "GENERIC" sysfs okur ama iGPU+dGPU busy'sini karıştırır, "None"
        # temiz).
        dashboard.performance.showGpu = false; # ikinci savunma hattı
        dashboard.showWeather = false; # periyodik ağ isteğini kes
        services.weatherLocation = "";
        background.visualiser.enabled = false; # sürekli PipeWire yakalaması yok
        background.desktopClock.enabled = false;

        # Bar: `power` girişi kapalı — PPD'nin tek yazarı power-display.service
        # kalsın (zaten üç root-taraflı yazarı var: power-display + game-perf +
        # ACAD udev). Menünün PPD'ye yazıp yazmadığı doğrulanmadı, ihtiyaten kapalı.
        bar.entries = [
          { id = "logo"; }
          { id = "workspaces"; }
          { id = "spacer"; }
          { id = "activeWindow"; }
          { id = "spacer"; }
          { id = "tray"; }
          { id = "clock"; }
          { id = "statusIcons"; }
          { id = "power"; enabled = false; }
        ];

        # Idle: yalnız lock + dpms. Uyku kararı logind'de kalır (s2h zinciri
        # system/kernel/power.nix'te kurulu). Caelestia'nın session menüsü zaten
        # logind D-Bus + suspendThenHibernate first-class destekli — ek koruma
        # gerekmiyor (systemctl/loginctl çağrıları D-Bus'a alias'lanıyor).
        general.idle = {
          lockBeforeSleep = true;
          inhibitWhenAudio = true;
          timeouts = [
            { timeout = 300; idleAction = "lock"; }
            {
              timeout = 480;
              idleAction = "dpms off";
              returnAction = "dpms on";
            }
          ];
        };

        general.apps.terminal = [ "ghostty" ];
        appearance.transparency = {
          enabled = true;
          base = 0.85;
          layers = 0.4;
        };
        paths.wallpaperDir = "~/Pictures/Wallpapers";
      };

      cli = {
        enable = true;
        package = cli-pkg;
        settings.theme = {
          enableTerm = true; # açık terminallere OSC dizileri
          enableHypr = true; # hypr/scheme/current.conf (kenarlık renkleri)
          enableGtk = true; # gtk.css + dconf (adw-gtk3-dark, Papirus)
          enableQt = true;
          enableBtop = true;
          enableFuzzel = true;
          enableDiscord = true; # vesktop tema CSS'i (canlı)
          enableChromium = false; # sudo -n gerektirir
          enableSpicetify = false; # Spotify yok
          enableHtop = false; # htoprc'yi komple ezer
          enableNvtop = false;
          enableWarp = false;
          enableZed = false;
          enablePandora = false;
          enableCava = false;
          postHook = "${themePostHook}";
        };
      };
    };

    # Kullanıcı template'i — dizin-konvansiyonu ile keşfedilir, bir config anahtarı
    # YOK. Çıktı yolu SEÇİLEMEZ: her zaman ~/.local/state/caelestia/theme/<basename>
    # (themePostHook bunu okuyor). Sözdizimi tuzağı: kullanıcı template'leri
    # {{ role.format }} kullanır (gen_replace_dynamic); paketlenmiş template'ler
    # {{ $name }} kullanır (gen_replace) — ikisi karıştırılmaz.
    xdg.configFile."caelestia/templates/kbd-color".source = ./templates/kbd-color;

    # --- Mutable-copy hilesi (nixy deseni, home/apps/vesktop.nix ile aynı) ---
    # shell.json'a (nexus GUI ayarları) runtime'da yazılır; HM symlink'i kalırsa
    # yazamaz. Switch sonrası symlink'i yazılabilir kopyayla değiştir, bayat
    # backup'ları ÖNCE sil (checkLinkTargets linkGeneration'dan önce koşar ve
    # bayat backup'ta hata verir).
    home.activation.caelestiaCleanBackups = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
      run rm -f "$HOME/.config/caelestia/shell.json.hm-backup"
    '';
    home.activation.caelestiaMutableConfigs = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      f="$HOME/.config/caelestia/shell.json"
      if [ -L "$f" ]; then
        run cp --remove-destination "$(readlink -f "$f")" "$f"
        run chmod u+w "$f"
      fi
    '';

    systemd.user.services.caelestia.Service.ExecStartPre = "${defaultsGuard}";
  };
}
