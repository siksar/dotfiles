# Fn tuşları — klavyenin satıcı kanalını (0xFF02) kullanılabilir hâle getirir.
#
# Ölçüm (16 Eyl 2026, Documentation/aerox16/fn-keys.md): Fn+F4 (mikrofon),
# Fn+F7 (performans/fan), Fn+F9 (touchpad) bu makinede YALNIZ satıcı sayfası
# 0xFF02 / Report ID 4 üzerinden geliyor. Linux o raporu evdev'e hiç çevirmez →
# üç tuş da işlevsizdi. Buradaki köprü raporu okuyup hem uinput tuşu üretir hem
# (--act) eylemi yapar.
#
# NEDEN EC DEĞİL: Fn matrisi EC'de değil, klavyenin kendi denetleyicisinde
# (0414:8104). On iki kombinasyonun hiçbiri EC'nin WMI olay kanalını
# tetiklemiyor — EC imajında tek bir HID descriptor bile yok. Yani bu iş
# `wmi.nix`'e ait değil, ayrı dosyada duruyor.
#
# NEDEN --act: saf tuş üretmek yetmedi; COSMIC KEY_MICMUTE / KEY_PROG1 /
# KEY_TOUCHPAD_TOGGLE'a hiçbir eylem bağlamıyor (ölçüldü). COSMIC tarafında
# kısayol tanımlanırsa `--act` gereksizleşir — o gün bayrağı kaldır, köprü saf
# tuş üreticisi olarak kalsın (doğru katman odur).
#
# BOŞTA GÜÇ (CLAUDE.md kural 6): köprü hidraw üzerinde BLOCKING read yapar —
# timer yok, yoklama yok, tuşa basılmadıkça uyanmaz. Servis de udev'le, klavye
# enumere olunca başlar.
{ pkgs, ... }:

let
  # Betik içeriği eval anında gömülür (`readFile`), store'a dosya olarak KOPYALANMAZ
  # → CLAUDE.md kural 2'nin "yeniden adlandırılamaz" kısıtı bu dosyaya İŞLEMEZ.
  # Shebang store perl'ine sabitlenir: `env perl` servis PATH'ine bağımlı olurdu.
  fn-bridge = pkgs.writeScriptBin "fn-bridge" (
    builtins.replaceStrings
      [ "#!/usr/bin/env perl" ] [ "#!${pkgs.perl}/bin/perl" ]
      (builtins.readFile ./fn-bridge.pl)
  );
in
{
  environment.systemPackages = [ fn-bridge ];

  systemd.services.aero-fn-bridge = {
    description = "AERO X16 Fn tuşları — 0xFF02 satıcı raporu → uinput + eylem";
    # wantedBy YOK: tetikleyici aşağıdaki udev kuralı. Klavye yoksa servis de yok,
    # yeniden başlatma döngüsüne girip boşta CPU yakmaz.
    serviceConfig = {
      Type = "simple";
      ExecStart = "${fn-bridge}/bin/fn-bridge --act --user zixar";
      # Klavye USB'den düşer/yeniden enumere olursa köprü ölür; udev yeniden
      # tetikler. on-failure + burst sınırı: kaybolan klavyede sonsuz retry yok.
      Restart = "on-failure";
      RestartSec = 2;
      # Mikrofon (wpctl) kullanıcı oturumunda, fan systemctl'le, touchpad i2c
      # bind/unbind ile — üçü de bu PATH'ten geliyor. pgrep: GNOME oturumunda
      # eylemi atlamak için (gnome.nix'teki "FN TUŞLARI ÇAKIŞMASI" notu).
      Environment = [
        "PATH=${
          pkgs.lib.makeBinPath [
            pkgs.util-linux # runuser
            pkgs.wireplumber # wpctl
            pkgs.systemd # systemctl
            pkgs.coreutils # env
            pkgs.procps # pgrep — GNOME oturumu tespiti
          ]
        }"
      ];
    };
    startLimitBurst = 3;
    startLimitIntervalSec = 60;
  };

  # Klavye enumere olunca başlat. Beş hidraw düğümünün hepsi aynı VID/PID taşır,
  # kural beşine de uyar — SYSTEMD_WANTS aynı birimi işaret ettiği için zararsız.
  services.udev.extraRules = ''
    SUBSYSTEM=="hidraw", ATTRS{idVendor}=="0414", ATTRS{idProduct}=="8104", \
      TAG+="systemd", ENV{SYSTEMD_WANTS}+="aero-fn-bridge.service"
  '';
}
