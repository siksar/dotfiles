# Grafik sudo parola istemi — tty'si olmayan bağlamlardan (Claude Code'un kabuğu,
# .desktop başlatıcı, systemd kullanıcı birimi) sudo çalıştırabilmek için.
# Bu bağlamlarda sudo parolayı okuyacak bir uçbirim bulamaz ve şununla ölür:
#   "sudo: a terminal is required to read the password"
#
# TUZAK 1 — SUDO_ASKPASS tanımlamak TEK BAŞINA YETMEZ. sudo(8) yardımcıyı yalnız
# `-A` bayrağıyla çağırır; bayraksız çağrı tty arar, bulamazsa yukarıdaki hatayla
# çıkar. Doğru kullanım her zaman `sudo -A …`. (sudo 1.9.17p2'de doğrulandı.)
#
# TUZAK 2 — environment.sessionVariables PAM oturum ortamına yazar; DEĞİŞKEN
# EKLENDİĞİNDE ZATEN AÇIK OLAN süreçler onu görmez. İlk switch'ten sonra yeniden
# giriş gerekir. Ara çözüm, değişkeni tek seferlik önüne koymaktır:
#   SUDO_ASKPASS=$(command -v ksshaskpass) sudo -A …
#
# Yardımcı seçimi: ksshaskpass Qt6/kf6 tabanlı.
#
# ⚠️ GEREKÇE 16 EYL 2026'DA ÇÜRÜDÜ, RAKAM YENİDEN ÖLÇÜLMELİ. Eski not şöyleydi:
# "ksshaskpass ... `desktop.plasma.enable` zaten açık olduğu için kf6 closure'da,
# marjinal maliyet 16.9 KiB (5 Eyl 2026, iki build + diff-closures)". O gün Plasma
# ağaçtan çıktı — kf6 yığınını artık BU ikili tek başına çekiyor olabilir, yani
# 16.9 KiB'lik rakam geçersiz. Ölçüm: `nix store diff-closures` ile bu dosyayı
# çıkarıp/koyarak iki build karşılaştır. Alternatif aday GNOME closure'ından:
# gcr'nin ssh-askpass'i (services.gnome.gcr-ssh-agent zaten açık) ya da seahorse.
# Değiştirmeden ÖNCE ölç — `sudo -A` bu makinedeki tek tty'siz sudo yolu.
# Wayland yerel çalışır (QT_QPA_PLATFORM oturumda "wayland;xcb").
{ pkgs, ... }:

let
  askpass = "${pkgs.kdePackages.ksshaskpass}/bin/ksshaskpass";
in
{
  environment.systemPackages = [ pkgs.kdePackages.ksshaskpass ];

  # Yalnız sudo. ssh için de aynı ikili kullanılabilir (SSH_ASKPASS) ama bu
  # dosya bilerek tek işe bakıyor — ssh'ın tty'siz davranışını değiştirmek
  # ayrı bir karardır.
  environment.sessionVariables.SUDO_ASKPASS = askpass;
}
