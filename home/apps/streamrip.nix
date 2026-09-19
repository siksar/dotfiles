# streamrip — Deezer (+ Qobuz/Tidal/SoundCloud) müzik indirici, CLI (komut: rip).
#
# NEDEN STREAMRIP, deemix/kmille'nin deezer-downloader'ı DEĞİL (13 Eyl 2026,
# GitHub'da 20+ aday tarandı — Deezy, godeez, deemix fork'ları dahil): bu
# flake'in PİNLEDİĞİ nixpkgs'te zaten paketli — `nix eval
# .#nixosConfigurations.nixos.pkgs.streamrip.version` ile doğrulandı (2.2.0,
# registry değil). Diğerlerinin hiçbiri nixpkgs'te yok; flake input (deemix)
# ya da python3Packages ile elle paketleme (kmille) gerektirirdi. Ayrıca en
# yüksek yıldız/aktiflik (4916 ★, son push 2026-08-04, GPL-3) ve tek araçla
# Qobuz/Tidal/SoundCloud'u da kapsıyor.
#
# KİMLİK BİLGİSİ REPO'YA YAZILMAZ: Deezer'a ARL çerezi ile giriş gerekiyor
# (Deezer hesabı → tarayıcı devtools → Application/Storage → cookie `arl`).
# `rip config open` ile ~/.config/streamrip/config.toml elle düzenlenir, Nix
# bu dosyaya dokunmaz — opencode.nix'teki secrets deseniyle aynı gerekçe
# (store dünyaya açık okunur, sır oraya gitmez).
#
# YASAL NOT: Deezer'ın (ve Qobuz/Tidal'ın) DRM korumalı akışını ARL/premium
# hesapla indirmek Kullanım Şartları'nı ihlal eder, hesap askıya alınabilir.
# Kişisel/eğitim amaçlı kullan — proje de sorumluluğu kullanıcıya bırakıyor.
#
# İDLE BÜTÇESİ DOKUNULMADI: systemd unit yok, yalnız CLI binary — çağrılmadan
# çalışmaz.
{ pkgs, ... }:

{
  home.packages = [ pkgs.streamrip ];
}
