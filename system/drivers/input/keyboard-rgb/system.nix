{ config, pkgs, ... }:

# Klavye aydınlatması — HID LampArray (Usage Page 0x59), tek bölge RGB.
# Ölçüm ve protokol notları: Documentation/aerox16/keyboard-rgb.md
#
# Neden WMI/EC değil: aorus-laptop sürücüsünde klavye desteği YOK ve WMBD
# 0xF6 (KBLL) tek bayt — en iyi ihtimalle parlaklık, renk değil. Klavye
# standart LampArray konuştuğu için renk işi tamamen HID tarafında.

let
  kbd-rgb = pkgs.callPackage ./package.nix { };

  # Animasyon aç/kapa — bind'lar bunu çağırır. Aynı mod tekrar çağrılırsa
  # kapatır (toggle), farklı mod istenirse öncekini durdurup yenisini açar.
  kbd-anim = pkgs.writeShellScriptBin "kbd-anim" ''
    set -eu
    mode="''${1:-breathe}"
    unit="kbd-rgb-anim@$mode.service"
    if systemctl --user is-active -q "$unit"; then
      systemctl --user stop "$unit"
    else
      # başka bir mod dönüyorsa önce onu durdur (ExecStopPost firmware'i iade eder)
      systemctl --user stop 'kbd-rgb-anim@*.service' >/dev/null 2>&1 || true
      systemctl --user start "$unit"
    fi
  '';
in
{
  environment.systemPackages = [ kbd-rgb kbd-anim ];

  # uaccess: /dev/hidraw'ı OTURUM AÇMIŞ kullanıcıya açar (logind ACL'i).
  # Böylece root/polkit/systemd zinciri gerekmiyor — fan_mode'un aksine,
  # çünkü orada sysfs düğümü root'a sabitti.
  #
  # ⚠️ SIRALAMA TUZAĞI (29 Tem'de bizzat yaşandı): `services.udev.extraRules`
  # kuralları `99-local.rules`'a yazar. systemd'nin etiketi ACL'e çeviren
  # kuralı `73-seat-late.rules`'ta (`TAG=="uaccess" … RUN{builtin}+="uaccess"`)
  # ve udev dosyaları LEKSİK sırayla işler → 73, 99'dan ÖNCE çalışır. Yani
  # etiket, onu tüketen kural geçtikten sonra eklenir ve ACL HİÇ uygulanmaz
  # (belirti: `sudo kbd-rgb` çalışır, kullanıcı olarak "Permission denied").
  # Bu yüzden kural 73'ten ÖNCE sıralanan kendi dosyasında olmak ZORUNDA.
  services.udev.packages = [
    (pkgs.writeTextFile {
      name = "kbd-rgb-udev-rules";
      destination = "/etc/udev/rules.d/70-kbd-rgb.rules";
      text = ''
        SUBSYSTEM=="hidraw", ATTRS{idVendor}=="0414", ATTRS{idProduct}=="8104", TAG+="uaccess"
      '';
    })
  ];

  # ── Tema köprüsü (11 Eyl 2026 — KOPMUŞTU, yeniden kuruldu) ─────────────────
  # 9 Ağu – Eyl 2026 arasında bu işi Caelestia'nın tema motoru yapıyordu: şema
  # değişince bir şablonu işleyip `kbd-rgb set <hex>` çağırıyordu. Caelestia
  # ağaçtan çıkınca o zincirin TAMAMI gitti ve klavye firmware efektinde kaldı —
  # sessizce, çünkü çağrı zaten dışarıdan geliyordu. Yerine tek atışlık servis:
  #
  # RENK Stylix'ten geliyor (base0D = vurgu rengi), yani kök CLAUDE.md'nin
  # "renklerin tek kaynağı Stylix" kuralı klavyeye de uzanıyor. Palet
  # `lib/theme.nix`'te değişince burası kendiliğinden takip eder.
  #
  # NEDEN TIMER/POLL DEĞİL (4.28W bütçesi): renk eval zamanında sabitlenir,
  # çalışma zamanında değişmez → oturum başına TEK yazma yeter, sonra süreç ölür.
  #
  # NEDEN graphical-session.target: oturuma özel değil, hem COSMIC hem Plasma'da
  # çalışsın diye. Ayrıca /dev/hidraw'ın uaccess ACL'i ancak oturum açıkken var —
  # daha erken bir hedefte "Permission denied" alırdık.
  # (Bu hedefe asılmak DÖNGÜ yaratmaz: ölçüldü — graphical-session.target kendi
  # Wants= listesine örtük After= almıyor, `systemctl --user show` ile doğrulandı.)
  systemd.user.services.kbd-rgb-theme = {
    description = "Klavye RGB rengini Stylix paletine eşitle";
    wantedBy = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${kbd-rgb}/bin/kbd-rgb set ${config.lib.stylix.colors.base0D}";
      # Klavye bir kez yazıldıktan sonra durumu kendi tutar; servis "aktif"
      # kalsın ki oturum kapanınca partOf ile temizlensin.
      RemainAfterExit = true;
    };
  };

  # Animasyon şablon servisi. `wantedBy` YOK ve boot'ta/oturumda AÇILMAZ —
  # 4.28W idle bütçesi gereği (CLAUDE.md): idle'da dönen hiçbir şey olamaz.
  # Yalnız kullanıcı SUPER+K ile tetikleyince çalışır.
  systemd.user.services."kbd-rgb-anim@" = {
    description = "Klavye RGB animasyonu (%i)";
    serviceConfig = {
      Type = "simple";
      ExecStart = "${kbd-rgb}/bin/kbd-rgb anim %i";
      # Durdurulunca firmware efektlerini iade et — böylece Rust tarafında
      # sinyal yakalamaya gerek kalmıyor.
      ExecStopPost = "${kbd-rgb}/bin/kbd-rgb auto on";
      Restart = "no";
      Nice = 10; # animasyon interaktif işten önce gelmesin
    };
  };
}
